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

class SendNotificationProcessor < ApplicationProcessor

  subscribes_to :instance_send_notification

  def on_message(message)
    logger.info("Received request to send an instance notification")
    
    hash = ActiveSupport::JSON.decode(message)

    instance = Instance.find_by_id(hash['merlin_instance_id'])
    template = NotificationTemplate.find_by_id(hash['template_id'])

    if instance.nil? or template.nil?
      logger.error("Could not locate instance or template: instance id #{hash['merlin_instance_id']}, template id #{hash['template_id']}")
      return
    end

    text = template.process(binding)

    begin
      e = EmailNotifier.create_send_notification(instance.cloud.notify_address,
                                                 text['subject'],
                                                 text['body'])
      
      EmailNotifier.deliver(e)
    rescue Exception => exc
      logger.error("Error processing notification: #{exc}")
    end

  end
end
