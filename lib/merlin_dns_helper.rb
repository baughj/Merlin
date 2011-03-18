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

require "ultradns4r"

module MerlinDnsHelper

  class DNSRecordNotFound < Exception
  end

  class DNSUpdateFailure < Exception
  end

  def connect_dns(identity, credential, api_url, api_usessl, provider_type)

    if provider_type == 'ultradns' then
      @dns_connector = MerlinDNSConnectors::MerlinUltraDNSConnector.new(:username => identity,
                                                                        :password => credential,
                                                                        :api_url => api_url,
                                                                        :api_usessl => true)
    elsif provider_type == 'bind' then
      @dns_connector = MerlinDNSConnectors::MerlinBINDConnector.new(:tsig_keyname => identity,
                                                                    :tsig_key => credential,
                                                                    :server => api_url)
    else
      raise RuntimeError, "Unsupported provider type #{provider_type}"
    end

  end

  def dns_request(function, *args)
    if @connector.nil?
      self.send(:connect)
      if @connector.nil?
        raise RuntimeError, "You must connect to a DNS endpoint first."
      end
    end

    begin
      resp = @connector.send(function, args)
    rescue Exception => exc
      logger.error "DNS API endpoint call #{function} reported error: " + exc
      @dns_error = exc
    end
  end
end
