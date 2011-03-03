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

require "open4"
require "AWS"
require "erb"
require "base64"

class MerlinController < ApplicationController

  def error
    api_request('wtf', true)
  end

  def index
    @instances = Instance.all
    @cloud = Cloud.new
    @clouds = Cloud
  end


  def launch
    
    if params[:submit] == 'Launch' then
      
      @instance = Instance.new(params[:instance])

      it = InstanceType.find(id=params[:instance_type])
      
      if Integer(params[:volume_type]) != 0 then
        # Make a new EBS volume, and add it to our instance
        
        vt = VolumeType.find(id=params[:volume_type])
        resp = api_request(:create_volume, true, 
                           :size => String(vt.size), 
                           :availability_zone => APP_CONFIG[:cloud_availability_zone])
        
        update_from_api(resp.volumeId)
        @volume = Volume.find_by_volume_id(resp.volumeId)
        @volume.mount_point = vt.mount_point
        @volume.device = vt.device
        @volume.fs = vt.fs
        @volume.save
        @instance.volumes.push @volume
      end
      
      # Prepare user data.
      begin
        userdata = ERB.new(File.open(APP_CONFIG[:userdata_template]){ |f| f.read}).result(binding)
        puts userdata
        userdata = Base64.encode64(userdata)
      rescue Exception => exc
        Rails.logger.error "Couldn't create userdata for instance request: #{exc}"
        flash.now[:error] = "Couldn't create userdata for instance request: #{exc}"
        return
      end

      # Run instance.

      Rails.logger.info "Creating #{it.bits}-bit instance (#{it.type}, #{it.instance_type})"

      resp = api_request(:run_instances, false, :image_id => it.image_id,
                         :key_name => APP_CONFIG[:instance_pubkey_id],
                         :security_group => @instance.sec_group,
                         :instance_type => it.instance_type,
                         :user_data => userdata,
                         :availability_zone => APP_CONFIG[:cloud_availability_zone])
      
      if not resp
        flash.now[:error] = "Instance creation failed: #{@api_error}"
        return
      end
      @instance.reservation_id = resp.reservationId
      @instance.request_id = resp.requestId
      @instance.instance_id = resp.instancesSet.item[0].instanceId
      @instance.launched = true
      @instance.save 
      
      flash.now[:notice] = "Instance #{@instance.instance_id} launched (reservation #{@instance.reservation_id})"
      
    end
    
  end
  
end
