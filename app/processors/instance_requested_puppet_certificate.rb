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

class InstanceRequestedPuppetCertificateProcessor < ApplicationProcessor

  subscribes_to :instance_requested_puppet_certificate

  def on_message(message)
    logger.info("Received request for signature of new Puppet cert")
    logger.debug("Received message: #{message}")

    hash = ActiveSupport::JSON.decode(message) 
    instance = Instance.find_by_id(hash['merlin_instance_id'])
    if instance.nil?
      logger.error("Couldn't locate instance with object id #{message.merlin_instance_id}...?")
      return
    end

    if instance.hostname.nil?
      logger.error("Puppet certsign requested on an instance with no hostname...?")
      return
    end

    begin
      # This next part makes a number of assumptions, which should probably be documented.
      # Once the Puppet CA API is fully implemented, we'll use that instead.
      # This code is also reckless and dangerous.
      if instance.cloud.puppet_capath.nil?
        ret = `sudo puppetca -s #{instance.hostname} 2>&1`
      else
        ret = `sudo #{instance.cloud.puppet_capath} -s #{instance.hostname} 2&>1`
      end
      if $?.exitstatus != 0
        instance.status_code = Instance::STATUS['error']
        instance.status_message = "Couldn't sign puppet certificate: check logs"
        logger.error("Unknown error signing certificate for #{instance.hostname}: #{ret}")
      else
        instance.status_message = "Puppet CA signed certificate"
      end
    rescue Exception => exc
      instance.status_code = Instance::STATUS['error']
      instance.status_message = "Error signing puppet certificate: #{exc}"
      logger.error("Unknown error signing certificate for #{instance.hostname}: #{exc}")
      instance.save
    end
    
    instance.save
  end
end
