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

require "yaml"

class Cloud < ActiveRecord::Base

  has_many :availability_zones
  has_many :instances
  has_many :volumes
  has_many :security_groups
  has_one :dns_provider
  belongs_to :cloud_type
  has_many :instance_types
  has_many :key_pairs
 
  include MerlinApiHelper
  
  ObjectQueryInfo = {'snap' => {'api_call' => :describe_snapshots,
      'api_arg' => 'snapshot_id', 'api_return' => 'snapshotSet'},
    'i' => {'api_call' => :describe_instances,
      'api_arg' => 'instance_id', 'api_return' => 'reservationSet'},
    'vol' => {'api_call' => :describe_volumes,
      'api_arg' => 'volume_id', 'api_return' => 'volumeSet'},
    'ami' => {'api_call' => :describe_images,
      'api_arg' => 'image_id', 'api_return' => 'imageSet'},
    'emi' => {'api_call' => :describe_images,
      'api_arg' => 'image_id', 'api_return' => 'imageSet'}
  }

  def api_ready?
    if @connector
      return true
    else
      return false
    end
  end

  def get_api_error
    if @api_error
      return @api_error
    else
      return nil
    end
  end

  def connect
    if not api_ready?
      logger.info("Connecting to API endpoint #{api_url}")
      connect_api(query_key_id, query_key, api_url, api_usessl, cloud_type.name)
    end
    return true
  end

  def object_exists?(object_id)
    prefix, id = object_id.split('-')
    prefix = prefix.downcase
    if not ObjectQueryInfo.keys.include? prefix
      return nil
    else
      if cloud_type.aws?
        f = api_request(ObjectQueryInfo[prefix].api_call, false, 
                           ObjectQueryInfo[prefix].api_arg.to_sym => object_id)
        return !f.nil?
      elsif cloud_type.eucalyptus?
        # This code for Eucalyptus needs to either cache and/or do this more intelligently, otherwise
        # it will choke on lengthy returns on large clouds. Eucalyptus doesn't seem to
        # support filtering for certain API calls so for right now we just suck it up and wait.
        # Note that calling describe_snapshots on EC2 for 7000+ snapshots can take up to 90 seconds,
        # so calling these from a web request is a spectacularly bad idea on large clouds.
        oinfo = api_request(ObjectQueryInfo[prefix].api_call, false,
                            ObjectQueryInfo[prefix].api_arg.to_sym => object_id)
        if oinfo[ObjectQueryInfo[prefix].api_return].nil?
          return false
        else
          # This is hugely inefficient, rite.
          return oinfo[ObjectQueryInfo[prefix].api_return].item.map { |i| i[ObjectQueryInfo[prefix].api_arg] }.include? object_id
        end
      end
    end
  end

  def update_from_api()
    logger.info("Cloud: #{name} requested API update.")

    connect

    zone_req = @connector.describe_availability_zones

    # Get our availability zones

    if cloud_type.name == 'eucalyptus' then
      # For whatever reason, Eucalyptus sometimes has different ways of
      # stating AZs depending on its config. Either it returns a string
      # representation of an array of zones (e.g. ['zone1', 'zone2'] or it
      # returns similar to EC2 (array of hashes).
      if zone_req.availabilityZoneInfo.item[0].zoneName == 'default'
        zones = YAML.load(zone_req.availabilityZoneInfo.item[0].zoneState)
        zones.each do |zone|
          AvailabilityZone.find_or_create_by_name_and_cloud_id(zone, id)
        end
      else
        zones = zone_req.availabilityZoneInfo.item
        zones.each do |zone|
          AvailabilityZone.find_or_create_by_name_and_cloud_id(zone.zoneName, id)
        end
      end
    elsif cloud_type.name == 'aws' then
      zones = zone_req.availabilityZoneInfo.item
      zones.each do |zone|
        AvailabilityZone.find_or_create_by_name_and_cloud_id(zone.zoneName, id)
      end
    end

    # Get keypairs

    @connector.describe_keypairs.keySet.item.each do |keypair|
      KeyPair.find_or_create_by_name_and_fingerprint_and_cloud_id(keypair.keyName,
                                                                  keypair.keyFingerprint,
                                                                  id)
    end

    # Get security groups
    @connector.describe_security_groups.securityGroupInfo.item.each do |secgroup|
      SecurityGroup.find_or_create_by_name_and_owner_id_and_cloud_id(secgroup.groupName,
                                                                     secgroup.ownerId,
                                                                     id)
    end

    # To minimize the number of API calls required, we don't use the volume/instance
    # update functions: we pull all the information for everything at once and update
    # using the information returned.

    rset = @connector.describe_instances.reservationSet

    if !rset.nil?
      rset.item.each do |reservationSet|
        # Each reservation set, remember, can have multiple instances
        reservationSet.instancesSet.item.each do |instance|
          i = Instance.find_by_instance_id(instance.instanceId)
          if i.nil?
            i = Instance.new(:instance_id => instance.instanceId)
            i.status_code = Instance::STATUS['running']
            i.status_message = "API refresh discovered new instance"
            i.cloud = self
          end
          i.update_properties(instance)
          # Set a few things that aren't simple assignments, this should be abstracted eventually
          logger.debug("instance #{instance.instanceId} has secgroup(s) #{reservationSet.groupSet.item.inspect}, vmType #{instance.instanceType}, keyPair #{instance.keyName}")
          i.vm_type = VmType.find_by_name_and_cloud_type_id(instance['instanceType'], self.cloud_type)
          i.key_pair = KeyPair.find_by_name_and_cloud_id(instance['keyName'], self)
          reservationSet.groupSet.item.each do |secgroup|
            i.security_groups << SecurityGroup.find_by_name_and_cloud_id(secgroup.groupId,
                                                                         self)
          end
          i.save
        end
      end
    end

    vset = @connector.describe_volumes.volumeSet

    if !vset.nil? 
      vset.item.each do |volume|
        v = Volume.find_or_create_by_volume_id(volume.volumeId)
        v.cloud = self
        v.update_properties(volume)
      end
    end

    # Snapshot support not done yet

    #@connector.describe_snapshots.snapshotSet.item.each do |snap|
    #end

  end
end
