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

module MerlinApiHelper

  class MerlinEC2Connector < AWS::EC2::Base
    # Implement some filtering here since the gem doesn't, yet
    def describe_volumes_with_filter(options = {})
      options = { :volume_id => [] }.merge(options)
      params = pathlist("VolumeId", options[:volume_id])
      if options [:filter]
        params.merge!(pathkvlist('Filter', options[:filter], 'Name', 'Value', {}))
      end
      return response_generator(:action => "DescribeVolumes", :params => params)
    end
  end

  class MerlinEucalyptusConnector < AWS::EC2::Base
    # Eucalyptus doesn't support the same API versions as EC2 currently
    #API_VERSION = '2009-11-30' # Eucalyptus 2
    API_VERSION = '2010-08-31' # Eucalyptus 3

    def api_version
      API_VERSION
    end

  end

  class APIObjectNotFound < Exception
  end

  def connect_api(access_key_id, 
                  access_key,
                  api_url,
                  usessl,
                  cloud_type)
    begin
      endpoint = URI.parse(api_url)
      logger.debug("Connecting to API endpoint at #{endpoint.host}, cloud type is #{cloud_type}")
      if cloud_type == 'eucalyptus' then
        @connector = MerlinEucalyptusConnector.new(:access_key_id => access_key_id,
                                                   :secret_access_key => access_key,
                                                   :server => endpoint.host,
                                                   :use_ssl => usessl,
                                                   :path => endpoint.path,
                                                   :port => endpoint.port)
      elsif cloud_type == 'aws' then
        @connector = MerlinEC2Connector.new(:access_key_id => access_key_id,
                                            :secret_access_key => access_key)
      end
    rescue Exception => exc
      logger.error "Error initiating endpoint connection: #{exc} #{exc.backtrace.join("\n")}"
      @api_error = exc
      return false
    end
    return true
  end

  def api_request(function, render_failure_xml, *args)

    if not @connector then
      # Classes which include this mixin can define a connect function which will be used
      # for class-specific connection info, e.g. Cloud defines a connect function that 
      # automatically connects with its stored information.
      self.send(:connect)
      if not @connector then
        raise RuntimeError, "You must connect to an API endpoint first, using api_connect." 
      end
    end

    begin
      resp = @connector.send(function, *args)
    rescue Exception => exc
      logger.error "API call #{function} reported error: " + exc
      @api_error = exc
      return false
      if render_failure_xml
        flash[:error] = "API call #{function} reported error: " + exc
       #respond_to do |format| format.xml and return
       render :template => 'merlin/xmlerror' and return
     end
      return
    end
    return resp
  end

end
