# This file is part of Merlin, an EC2 API-compatible cloud
# computing frontend.
#
# merlin - the only limit is the sky
# Copyright (C) 2011 Justin Baugh <baughj@discordians.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License along with this program.
#
# If not, see <http://www.gnu.org/licenses/>.
#

require 'password'

class Instance < ActiveRecord::Base
  cattr_reader :per_page
  @@per_page = 25

  belongs_to :availability_zone
  belongs_to :cloud
  has_many :volume
  has_and_belongs_to_many :security_group
  belongs_to :instance_type
  belongs_to :vm_type
  belongs_to :userdata
  belongs_to :key_pair

  # Define some status constants. We combine a bunch of different Merlin-specific states
  # with the typical EC2 states. 
  #
  # Here is some explanation:
  #
  # error         Error state. In most cases, status_message should say why 
  #               the instance is in this condition.
  # pending       Instance is pending on the cloud.
  # requested     Instance has been requested (e.g. created by Merlin) but not yet
  #               reserved on the cloud.
  # reserved      Instance has been reserved on the cloud (e.g. has a
  #               reservation/instance_id).
  # provisioning  Userdata script is running. This is the state after the
  #               instance uses the "hello" API call, if you are using the
  #               default userdata script.
  # provisioned   Userdata script is complete. If there were no errors running
  #               the script, the instance is only in this state briefly,
  #               before it moves to "active" (it moves to active when the instance
  #               makes a "completed" API call).
  # active        This state is used to represent an instance that is not only
  #               known to be running, but has been correctly provisioned.
  # ghost         This state is used to represent an instance that still exists,
  #               but for some reason no longer exists on the cloud. Merlin is not
  #               aggressive about removing ghost instances, in case useful
  #               information remains in the instance object.
  # running       An instance that is running. Beyond that, Merlin cannot say.
  #               This is the default state for new instances discovered via a
  #               refresh from the cloud API endpoint.
  #
  # The rest of the status codes mean exactly what they say; they are mirrors of
  # the EC2 API documentation.
  #

  STATUS = {'error' => -1,
    'pending' => 0,
    'requested' => 1,
    'reserved' => 2,
    'provisioning' => 5,
    'provisioned' => 6,
    'active' => 7,
    'ghost' => 9,
    'running' => 16,
    'shutting-down' => 32,
    'terminated' => 48,
    'stopping' => 64,
    'stopped' => 80,
  }

  STATUS_REVERSE = STATUS.invert

  # These variables will always be updated from the endpoint.
  ENDPOINT_UPDATE = ['instanceId', 'kernelId', 'ImageId', 'ramdiskId', 'launchTime', 'privateDnsName', 'dnsName',
                     'privateIpAddress', 'ipAddress', 'rootDeviceName', 'rootDeviceType',
                     'ownerId', 'architecture', 'virtualizationType', 'reason']

  def exists?
    # Has the instance been invoked (assigned a cloud instance ID, e.g. i-13371337)?
    # If it has an ID, does the remote API know about it?

    if instance_id.nil?
      return false
    else
      return cloud.object_exists? instance_id
      end
  end

  def generate_access_token
    self.access_token = Password.random(64)
    self.save
  end

  def generate_userdata
    begin
      raw = ERB.new(userdata.script).result(binding)
      self.raw_userdata = Base64.encode64(raw)
      self.save
    rescue Exception => exc
      @userdata_error = "Error processing userdata: #{exc}"
      return nil
    end
  end

  def running?
  end

  def stopped?
  end

  def pending?
  end

  def update_dns

  end

  def update_properties(i_info)
    # Update an instance's properties from a hash containing an InstancesSet.item. 
    # This is a separate function so it can be used by Cloud.update_from_api so 
    # we don't have to make multitudes of API calls simply to enumerate the 
    # current state of the cloud.

    ENDPOINT_UPDATE.each do |var|
      self.send("%s=" % var.underscore, i_info[var])
    end

    # Eucalyptus stores IP addresses in dnsName instead, apparently

    if cloud.cloud_type.eucalyptus?
      self.private_ip_address = i_info['privateDnsName']
      self.ip_address = i_info['dnsName']
    end

    self.key_pair = KeyPair.find_by_name(i_info.keyName)
    self.availability_zone = AvailabilityZone.find_by_name(i_info.placement['availabilityZone'])

    # Update our status if appropriate

    if [STATUS['requested'], STATUS['reserved'], STATUS['pending'], STATUS['terminated'], STATUS['ghost'], STATUS['stopped']].include? status_code
      # If this instance has completed a script run, mark as active; otherwise, mark it as running (implying it needs to be provisioned).
      # Future status checks here might see if Puppet is running / has ever run, etc.
      if has_run_userdata
        self.status_code = STATUS['active']
        self.status_message = "API refresh marked instance as active."
      else
        self.status_code = STATUS['running']
        self.status_message = "API refresh marked instance as running, but userdata appears to have not completed. May need manual intervention."
      end
    end

    self.save
    return true
  end

  def update_from_api(update_volumes=true)
    # Update our local information on an instance from the API.

    # Need to check this: we need to be sure we are collecting request_id, reservation_id,
    # vm_type_id, instance_type_id, dnsName, privateDnsName, blockDeviceMapping, rootDeviceName,
    # rootDeviceType, monitoring, instanceType, instanceState.name, ownerId

    if instance_id.nil?
      logger.error("API update requested on instance that does not have a cloud ID!")
      return false
    end

    api_info = cloud.api_request(:describe_instances, false, :instance_id => instance_id)
    rset = api_info.reservationSet.item
    i_info = nil

    if rset.length > 0
      # Cloud doesn't support filtering (Euca), so we have to do this the hard way
      if !i.reservation_id.nil?
        i_info = rset.select {|i| i['reservationId'] == i.reservation_id}[0]
      elsif i_info.nil?
        # We either don't have the reservation_id or the instance cannot be located by it,
        # so now we look for the instance ID itself
        i_info = rset.map {|i| i.instancesSet.item[0]}.select {|j| j.instanceId == instance_id}[0]
        if i_info.nil?
          logger.error("API couldn't locate instance information for reservation #{reservation_id}, instance #{instance_id}...? Marking as ghost!")
          status_code = STATUS['ghost']
          status_message = "Marked as ghost, API returned no information about #{reservation_id} or instance #{instance_id}"
          return false
        end
      end
    else
      i_info = api_info.reservationSet.item[0]
    end

    self.update_properties(i_info)

    if update_volumes
      if cloud.cloud_type.aws? then
        v_info = cloud.api_request(:describe_volumes_with_filter, false,
                                   :filter => [{'attachment.instance-id' => instance_id}])
        v_info.volumeSet.item.each do |volume|
          vol = Volume.find_or_create_by_volume_id(volume.volumeId)
          vol.update_from_api
        end
      elsif cloud.cloud_type.eucalyptus?
        # There are two ways to do this, depending on the version of Eucalyptus.
        # If the version is the latest, blockDeviceMapping is returned for the instance.
        # Else, you have to wade through the full output of describeVolumes.
        if i_info.blockDeviceMapping.nil?
          a_info = cloud.api_request(:describe_volumes, 
                                     false).volumeSet.item.select {
            |a| !a.attachmentSet.nil?}.map{ 
            |b| b.attachmentSet.item }
          # a_info is an array of attachmentSet items
          a_info.each do |attachment|
            vol = Volume.find_or_create_by_volume_id(attachment.volumeId)
            vol.update_from_api
          end
        else
          i_info.blockDeviceMapping.item.each do |mapping|
            # Ignore instance storage or non-standard Euca returns, we are ONLY interested in
            # knowing what EBS volumes are attached to the instance
            if !mapping.ebs.nil?
              vol = Volume.find_or_create_by_volume_id(mapping.ebs.volumeId)
              vol.update_from_api
            end
          end
        end
      end
    end

    self.needs_api_update = false
    self.save
    return true

  end

  def reserve
    if !instance_id.nil?
      logger.error("Instance #{instance_id} requested reservation, but already has a cloud instance ID. Aborting.")
      return false
    end
    
    if status_code != 1 and status_code != -1 then
      logger.error("Reserve requested for instance that is not waiting for reservation status (or in an error state). Aborting.")
      return false
    end
    
    generate_access_token
    generate_userdata
    
    if raw_userdata.nil? then
      self.status_code = STATUS['error']
      self.status_message = @userdata_error
      self.save
      return false
    end
    
    
    logger.info("Requesting creation of instance (#{instance_type.vm_type.name}, image #{image_id})")
    
    run_instance_options ={
      :key_name => key_pair.name,
      :user_data => raw_userdata,
      :instance_type => instance_type.vm_type.name,
      :availability_zone => availability_zone.name
    }
    
    if cloud.cloud_type.support_multiple_sec_groups then
      run_instance_options.merge! :security_group => security_group.map { |sg| sg.name }
    else
      run_instance_options.merge! :security_group => security_group[0].name
    end
    
    if image_id then
      run_instance_options.merge! :image_id => image_id
    else
      run_instance_options.merge! :image_id => instance_type.image_id
    end
    
    logger.debug("Calling run_instance with parameters: #{run_instance_options.inspect}")
    
    r = cloud.api_request(:run_instances, false, run_instance_options)
    
    if r.nil?
      logger.debug("Instance reservation request failed: #{cloud.get_api_error}")
      self.status_code = STATUS['error']
      self.status_message = "Instance reservation request FAILED: #{cloud.get_api_error}"
      self.save
      return false
    else
      self.reservation_id = r.reservationId
      self.instance_id = r.instancesSet.item[0].instanceId
      self.status_code = STATUS['pending']
      self.status_message = "Reservation successful: #{r.reservationId}"
      self.save
      return true
    end
  end
end
