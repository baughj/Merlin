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

class InstanceRequestedDnsUpdateProcessor < ApplicationProcessor

  subscribes_to :instance_requested_dns_update

  def on_message(message)
    logger.info("Received request to update DNS for instance.")
    logger.debug("Received message: #{message}")

    hash = ActiveSupport::JSON.decode(message) 
    instance = Instance.find_by_id(hash['merlin_instance_id'])
    if instance.nil?
      logger.error("Couldn't locate instance with object id #{message.merlin_instance_id}...?")
      return
    end

    if instance.hostname.nil?
      logger.error("DNS update requested, but no hostname is defined.")
      return
    end

    logger.info("Requesting DNS update: #{instance.instance_id}, #{instance.hostname}")

    instance.update_dns

  end
end
