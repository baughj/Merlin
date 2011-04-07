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

class InstanceRequestedApiUpdateProcessor < ApplicationProcessor

  subscribes_to :instance_requested_api_update

  def on_message(message)
    logger.info("Received request to update instance from API endpoint.")
    logger.debug("Received message: #{message}")

    hash = ActiveSupport::JSON.decode(message) 
    instance = Instance.find_by_id(hash['merlin_instance_id'])
    if instance.nil?
      logger.error("Couldn't locate instance with object id #{message.merlin_instance_id}...?")
    end
    if hash.has_key? 'update_type' and hash['update_type'] == "metadata"
      logger.info("Metadata update requested for instance #{instance.instance_id}")
      instance.update_from_api(false)
    else
      logger.info("Full update requested for instance #{instance.instance_id}")
      instance.update_from_api
    end
  end
end
