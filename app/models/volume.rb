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

  def exists?
    if volume_id.nil?
      return false
    else
      return cloud.object_exists? volume_id
    end
  end

  def available?
  end

  def attached?
  end

  def update_attachment_properties(a_info)
    # Given a AttachmentSet.item, update the volume's attachment information.
    self.attachment_status_code = ATTACHMENT_STATUS[a_info.status]
    self.attachment_status_message = "Marked as attached by API update"
    self.attachment_attach_time = a_info.attachTime
    self.attachment_device = a_info.device
    self.delete_on_termination = a_info.deleteOnTermination
    self.instance = Instance.find_by_instance_id(a_info.instanceId)
    self.root_device = self.attachment_device == self.instance.root_device_name
    self.save
    return true
  end

  def update_properties(v_info)
    # Given a VolumeSet.item, update the volume.

    ENDPOINT_UPDATE.each do |var|
      self.send("%s=" % var.underscore, v_info[var])
    end
    
    self.status_code = STATUS_REVERSE[v_info.status]
    self.save
    
    if !v_info.attachmentSet.nil?
      update_attachment_properties v_info.attachmentSet.item[0]
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
      v_info = cloud.api_request(:describe_volumes, false, :volume_id => volume_id).volumeSet.item.select { |v| v.volumeId = volume_id } 
    end
    update_properties(v_info)
  end
  
end
