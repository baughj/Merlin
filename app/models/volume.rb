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

class Volume < ActiveRecord::Base
  belongs_to :instance
  belongs_to :availability_zone
  belongs_to :cloud
  has_one :volume_type

  # Define some status constants

  STATUS = {'error' => -1,
    'requested' => 1,
    'creating' => 2,
    'available' => 3,
    'in-use' => 4,
    'deleting' => 5,
    'deleted' => 6}

  ATTACHMENT_STATUS = {'error' => -1,
    'detached' => 2,
    'detaching' => 3,
    'attached' => 4,
    'attaching' => 5}

  STATUS_REVERSE = STATUS.invert
  ATTACHMENT_STATUS_REVERSE = ATTACHMENT_STATUS.invert

  ENDPOINT_UPDATE = ['volumeId', 'size', 'createTime', 'snapshotId']

  def pretty_print
    if name
      return "#{volume_id} (size: #{size}GB, name #{name})"
    else
      return "#{volume_id} (size: #{size}GB)"
    end
  end

  def get_error 
    return @volume_error
  end

  def exists?
    if volume_id.nil?
      return false
    else
      return cloud.object_exists? volume_id
    end
  end

  def available?
   return status == STATUS['available']
  end

  def attached?
    return status == STATUS['in-use']
  end

  def update_attachment_properties(a_info)
    # Given a AttachmentSet.item, update the volume's attachment information.
    self.attachment_status_code = ATTACHMENT_STATUS[a_info.status]
    self.attachment_status_message = "Marked as attached by API update"
    self.attachment_attach_time = a_info.attachTime
    self.attachment_device = a_info.device
    self.delete_on_termination = a_info.deleteOnTermination
    self.instance = Instance.find_by_instance_id(a_info.instanceId)
    self.instance.volume.push(self)
    self.root_device = self.attachment_device == self.instance.root_device_name
    self.save
    return true
  end

  def clear_attachment
    # "Clear" an attachment, removing its association with an instance and
    # removing its attachment information.
    self.instance.volume.delete(self)
    self.instance = nil
    self.attachment_status_code = nil
    self.attachment_status_message = "Marked as detached by API update"
    self.attachment_attach_time = nil
    self.save
  end

  def update_properties(v_info)
    # Given a VolumeSet.item, update the volume.

    ENDPOINT_UPDATE.each do |var|
      self.send("%s=" % var.underscore, v_info[var])
    end

    # Update our availability zone

    self.availability_zone = AvailabilityZone.find_by_name(v_info['availabilityZone'])
    self.status_code = STATUS[v_info.status]
    self.save

    if !v_info.attachmentSet.nil?
      update_attachment_properties v_info.attachmentSet.item[0]
    else 
      # Volume is unattached, mark it as such
      clear_attachment
    end
  end

  def update_from_api
    # Update our volume information from the API.

    if volume_id.nil?
      logger.error("API update requested on volume that doesn't have a cloud ID!")
      return false
    end

    if cloud.cloud_type.aws?
      v_info = cloud.api_request(:describe_volumes, false, :volume_id => volume_id).volumeSet.item[0]
    elsif cloud.cloud_type.eucalyptus?
      v_info = cloud.api_request(:describe_volumes, false, :volume_id => volume_id).volumeSet.item.select { |v| v.volumeId == volume_id }[0]
    end
    update_properties(v_info)
    return true
  end

  def detach
    # Detach a volume from an instance.
    if instance.nil?
      @volume_error = "This volume isn't associated with an instance."
      return false
    end

    if available?
      @volume_error = "Volume is marked as available?"
      return false
    end

    resp = cloud.api_request(:detach_volume, false, :volume_id => volume_id,
                             :instance_id => instance_id,
                             :device => attachment_device)
    if !resp
      @volume_error = "Volume could not be attached: #{cloud.get_api_error}"
      return false
    end

    clear_attachment
    return true
  end

  def attach
    # Make an API request to attach this volume to its associated instance.
    if instance.nil?
      @volume_error = "This volume isn't associated with an instance."
      return false
    end

    if attached? or !available?
      @volume_error = "This volume is not available. Status is #{STATUS_REVERSE[status_code]}, should be available."
    end

    if cloud.cloud_type.multiple_volumes?

      if !cloud.api_request(:attach_volume, false, :volume_id => volume_id,
                            :instance_id => instance_id,
                            :device => attachment_device)
        @volume_error = "Volume could not be attached: #{cloud.get_api_error}"
        return false
      end
    else
      raise RuntimeError, "Cloud type doesn't allow attachment of multiple volumes - detach existing volumes first."
    end

    return true
  end

  def reserve
    # Reserve the storage on the cloud, if it doesn't already exist.

    if !volume_id.nil?
      @volume_error = "Volume already has a cloud ID, can't complete reservation."
      return false
    end

    # This should be done in a validator, rite.
    if self.size < 1
      @volume_error = "Size of the requested volume must be at least 1GB."
      return false
    end

    if !availability_zone.nil?
      if !instance
        @volume_error = "The availability zone for this storage could not be determined."
        return false
      else
        availability_zone = instance.availability_zone
      end
      self.save
    end

    resp = cloud.api_request(:create_volume, false,
                             :availability_zone => availability_zone.name,
                             # amazon-ec2 gem for whatever reason wants size as a string
                             :size => size.to_s,
                             :snapshot_id => snapshot_id)
    if !resp
      @volume_error = "API endpoint reported error creating volume: #{cloud.get_api_error}"
      return false
    end

    self.volume_id = resp['volumeId']
    self.request_id = resp['requestId']
    self.status_code = STATUS_REVERSE[resp['status']]
    self.availability_zone = AvailabilityZone.find_by_name(resp['availabilityZone'])
    self.create_time = resp['createTime']
    self.save

    return true
  end

end
