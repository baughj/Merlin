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

class InstanceRequestedReservationProcessor < ApplicationProcessor

  subscribes_to :instance_requested_reservation

  def on_message(message)
    logger.info("Received request to reserve new instance.")
    logger.debug("Received message: #{message}")

    hash = ActiveSupport::JSON.decode(message) 
    instance = Instance.find_by_id(hash['merlin_instance_id'])
    if instance.nil?
      logger.error("Couldn't locate instance with object id #{message.merlin_instance_id}...?")
    end
    if instance.instance_id then
      if instance.cloud.object_exists? instance.instance_id
        logger.error("Instance is already invoked..? Has a cloud identifier, #{instance.instance_id} - aborting")
        instance.status_message = 'Error: Requested invocation of already invoked instance..?'
        instance.status_code = Instance::STATUS['error']
      else
        logger.error("Instance #{instance.id} has instance ID #{instance.instance_id} but does not exist on API endpoint...?")
        instance.status_message = 'Error: Instance is a ghost!'
        instance.status_code = Instance::STATUS['ghost']
      end
    end

    logger.info("Reserving: cloud #{instance.cloud.name}, zone #{instance.availability_zone.name}, hostname #{instance.hostname}")
    instance.reserve
  end
end
