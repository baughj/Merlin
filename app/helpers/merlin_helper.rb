# This file is part of Merlin, an EC2 API-compatible cloud
# computing frontend.
#
# Copyright (C) 2010, Justin Baugh <baughj@discordians.net>
#
# Merlin is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

require "AWS"

module MerlinHelper

  def get_api_connection
    begin
      ec2 = AWS::EC2::Base.new(:access_key_id => APP_CONFIG[:cloud_keyid],
                               :secret_access_key => APP_CONFIG[:cloud_key],
                               :server => APP_CONFIG[:cloud_api_endpoint],
                               :usessl => APP_CONFIG[:cloud_api_usessl])
    rescue Exception => exc
      return nil

    end
  end
  
  def get_instance_types 
    ret = []
    types = InstanceType.all()
    types.each do |type|
      ret.push(["#{type.name} #{type.version} (#{type.bits}-bit, #{type.instance_type}, #{type.region})", type.id])
    end

    return ret
  end


  def get_security_groups 
    begin
      ec2 = get_api_connection
    rescue Exception => exc
      return "<p>Error occurred retrieving security groups.</p>"
    end

    ret = []

    ec2.describe_security_groups.securityGroupInfo.item.each do |entry|
      ret.push(entry.groupName)
    end

    return ret
  end

  def get_volume_options
    
    ret = [ ["No additional volumes", 0] ]

    types = VolumeType.all()
    types.each do |type|
      ret.push(["#{type.size}GB (#{type.name})", type.id])
    end

    return ret

  end

end
