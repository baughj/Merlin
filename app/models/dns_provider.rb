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

class DNSProvider < ActiveRecord::Base
  include MerlinDnsHelper

  enum_attr :provider_type, %w(ultradns bind)
  has_many :clouds

  def api_ready?
    return !@connector.nil?
  end

  def connect
    if not api_ready?
      logger.info("Connecting to DNS provider #{api_url}")
      connect_dns(identity, credential, api_url, api_usessl, provider_type)
    end
    return true
  end

  def update_dns_for_instance(instance)
    # This needs to be expanded to correctly handle public/private dns,
    # at the moment it does what I need it to do.
    connect
    if create_a_record?
      create_dns_record(instance.hostname, instance.ip_address)
    else
      create_dns_record(instance.hostname, instance.dns_name, true)
    end
  end

  def create_dns_record(hostname, target, is_alias=false)
    # We do a couple of checks here.
    # 1) If the hostname doesn't contain any elements in common with our zone,
    # we submit an update for shortname.zone (e.g. foo.bar.baz -> quux.com would become
    # foo.quux.com)

    parts = hostname.split('.')
    shortname, domain = parts.slice!(0), parts

    if (domain | update_zone.split('.')).length == 0:
        hostname = "#{shortname}.#{update_zone}"
    end

    if is_alias
      @resp = dns_request(:create_alias, hostname, target, record_ttl)
    else
      @resp = dns_request(:create_cname, hostname, target, record_ttl)
    end

    if @resp.nil?
      self.status_code = STATUS['error']
      self.status_message = "DNS provider reported error: #{@dns_error}"
      self.save
      return false
    end

    return true
  end

end

