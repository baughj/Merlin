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
require "ultradns4r"

class InstancesController < ApplicationController
  include ActiveMessaging::MessageSender

  def create
    Rails.logger.info "Requesting creation of new instance.."
    Rails.logger.debug params.to_s
    @instance = Instance.new(params[:instance])
    if @instance.save
      publish :instance_requested_reservation, {'merlin_instance_id' => @instance.id}.to_json
      @instance.status_code = Instance::STATUS['requested']
      @instance.status_message = "Submitted creation request to Merlin."    
      @instance.save
      flash[:notice] = "Instance request submitted."
      render :action => "index"
    else
      render :action => "new"
    end

  end

  def datatable
  end

  def index
    if params[:format] == 'json'
      logger.debug('Rendering JSON instance list')
      @objects = current_objects(params)
      @total_objects = total_objects(params)
      render :template => "instances/datatable.html.erb", :layout => false and return
    end
    render :template => "merlin/index-new.erb" and return
  end

  def launch
    puts params
  end

  def hello

    # Do a couple of sanity checks first

    if !params[:id].nil?
      @instance = Instance.find_by_instance_id(params[:id])
    end

    if @instance.nil?
      flash.now[:error] = "An instance ID must be specified."
      render :template => "merlin/hello_error" and return
    end

    if !params[:access_token].nil?
      if @instance.access_token != params[:access_token]
        flash.now[:error] = "Invalid access token for instance #{@instance.id}"
        render :template => "merlin/hello_error" and return
      end
    else
      flash.now[:error] = "An access token must be provided."
      render :template => "merlin/hello_error" and return
    end

    if @instance.status_code != Instance::STATUS['running'] and 
        @instance.status_code != Instance::STATUS['pending'] then
      @instance.status_code = Instance::STATUS['error']
      @instance.status_message = "hello error: Instance requested hello but was not in a pre-provisioned state...?"
      @instance.save
      flash.now[:error] = "Instance status is marked as #{Instance::STATUS_REVERSE[@instance.status_code]} (should be pending/running). Aborting."
      render :template => "merlin/hello_error" and return
    end

    # Since the user data script is obviously running, we set our status as provisioning
    @instance.status_code = Instance::STATUS['provisioning']

    if @instance.hostname.nil?
      @instance.hostname = params[:hostname]
    end

    # Send two requests: Collect information that wasn't available when the instance was pending,
    # and update DNS if applicable.

    @instance.needs_api_update = true
    publish :instance_requested_api_update, {'merlin_instance_id' => @instance.id}.to_json
    publish :instance_requested_dns_update, {'merlin_instance_id' => @instance.id}.to_json
    render :template => "merlin/hello_success" and return

  end

  def init

    @res = {}

    if params[:id]
      i = api_request(:describe_instances, true)
    else
      flash.now[:error] = "An instance ID must be specified."
      render :template => 'merlin/xmlerror' and return
    end

    @instance = Instance.find_by_instance_id(params[:id])

    if @instance
      if not @instance.launched
        @res[@instance.instance_id] = ["FAIL", 
                                       "Instance was not launched by Merlin, but is unknown to Merlin. Instance will not be registered."]

        render :template => 'merlin/xmlresponse' and return
      elsif @instance.puppetized
        @res[@instance.instance_id] = ["FAIL", 
                                       "Instance already registered as #{@instance.hostname} and is known to Puppet. Instance will not be re-registered."]
        render :template => 'merlin/xmlresponse' and return
      end
      
      # Gather information we couldn't get on the instance when it was
      # pending - such as its IP addresses and info about its root device.
      # Calling update_from_api for an instance ID will also update all of its
      # volume information.

    else
      if params[:hostname].nil?
        @res[@instance.instance_id] = ["FAIL", "Instance is not registered with Merlin - hostname must be specified."]
        render :template => 'merlin/xmlresponse' and return
      end
    end

    if not update_from_api(params[:id])
      @res[@instance.instance_id] = ["FAIL", "Couldn't retrieve information on instance: #{@error}"]
      render :template => 'merlin/xmlresponse' and return
    end
    
    @instance = Instance.find_by_instance_id(params[:id])

    if params[:hostname]
      @instance.hostname = params[:hostname]
    end

    # Now, attempt to update DNS
    if not dns_create_record(@instance.hostname,
                             @instance.external_ip,
                             true)
      @res[@instance.instance_id] = ["WARNING", "External DNS could not be updated: %s" % @dns_error]
    end
    
    r = api_request(:authorize_security_group_ingress, false, 
                    :group_name => APP_CONFIG[:cloud_secgroup],
                    :ip_protocol => "tcp",
                    :from_port => APP_CONFIG[:puppet_port],
                    :to_port => APP_CONFIG[:puppet_port],
                    :cidr_ip => "#{@instance.external_ip}/32")
    if not r
      if @api_error.is_a? AWS::InvalidPermissionDuplicate
        # Ignore permission duplicate error
        render :template => 'merlin/xmlresponse' and return
      else
        @res[@instance.instance_id] = ["FAIL", "API reported error authorizing group ingress.  " + @api_error]
        render :template => 'merlin/xmlresponse' and return
      end
    end
        
    @res[@instance.instance_id] = ["SUCCESS", "Endpoint request ID: #{r.requestId}"]
    render :template => 'merlin/xmlresponse' and return
      
    end
    
  def signkey
    @action = 'signkey'
    @instance = Instance.find_by_instance_id(params[:id])

    @res = {}

    if not @instance then
      @res[params[:id]] = ["FAIL", "Instance #{params[:id]} is not registered - use init first."]
      render :template => 'merlin/xmlresponse' and return
      return
    end
    
    begin
      pid, stdin, stdout, stderr = open4.popen4("sudo #{APP_CONFIG[:puppet_ca_binpath]} -s #{@instance.hostname}")
      p, status = Process.waitpid2(pid)
      puts stdout.read()
      if status.to_i != 0 then
        @res[params[:id]] = ["FAIL", "puppetca binary returned error: #{stderr.read()}"]
      else
        @res[params[:id]] = ["SUCCESS", "Puppet CA signed certificate for instance #{@instance.instance_id} (#{@instance.hostname})"]
      end
    rescue Exception => exc
      @res[params[:id]] = ["FAIL", "Unhandled exception while signing certificate: #{exc}"]
    end
    
    render :template => 'merlin/xmlresponse' and return
  end

  
  def attachStorage
    update_from_api(params[:id])
    @instance = Instance.find_by_instance_id(params[:id])
    
    @res = {}
    # Always make an API call to attach the storage, even if the 
    # status is attached.
    
    @instance.volumes.each { |volume|
      if not api_request(:attach_volume, false, :volume_id => volume.volume_id,
                         :instance_id => @instance.instance_id,
                         :device => volume.device)
        s_error = String(@api_error)
        if s_error['already attached']
          @res[volume.volume_id] = ["SUCCESS", 
                                    "Volume already attached."]
        else
          @res[volume.volume_id] = ["FAIL", s_error]
        end
      else
        @res[volume.volume_id] = ["SUCCESS", "Volume attached."]
        
        
      end
    }
    render :template => 'merlin/xmlresponse' and return
  end

  def complete
    @action = 'complete'
    @res = {}
    @instance = Instance.find_by_instance_id(params[:id])
    @instance.puppetized = true
    @instance.active = true
    @instance.save
    mail = Notifier::create_instance_ready(APP_CONFIG[:notify_address], @instance)
    Notifier.deliver(mail)
    @res[@instance.instance_id] = ['SUCCESS', 'Provisioning complete.']
    render :template => 'merlin/xmlresponse' and return
  end

  def intervene
    puts "Notifying #{APP_CONFIG[:notify_address]}"
    @action = 'intervene'
    @res = {}
    @instance = Instance.find_by_instance_id(params[:id])
    @instance.puppetized = false
    @instance.active = false
    @instance.save
    mail = Notifier::create_intervention_needed(APP_CONFIG[:notify_address], @instance)
    Notifier.deliver(mail)
    @res[@instance.instance_id] = ['SUCCESS', 'Requested administrative intervention for instance.']
    render :template => 'merlin/xmlresponse' and return
  end

  def xml
    @instances = Instance.all
    render :template => 'merlin/xml_instance_list' and return
  end

  def new 
    @instance = Instance.new
    render :template => 'merlin/create_instance' and return
  end

  private
  
  def current_objects(params={})
    current_page = (params[:iDisplayStart].to_i/params[:iDisplayLength].to_i rescue 0)+1
    @current_objects = Instance.paginate :page => current_page,
    :order => "#{datatable_columns(params[:iSortCol_0])} #{params[:sSortDir_0] || "DESC"}",
    :conditions => conditions,
    :per_page => params[:iDisplayLength]
  end

  def total_objects(params={})
    @total_objects = Instance.count :conditions => conditions
  end

  def datatable_columns(column_id)
    case column_id.to_i
    when 0
      return "instances.status_code"
    when 1
      return "instances.instance_id"
    when 2
      return "instances.hostname"
    when 3
      return "instances.hostname"
    else
      return "instances.hostname"
    end
  end

  def conditions
    conditions = []
    if (params[:sSearch] != "")
      conditions << "(instances.hostname ILIKE '%#{params[:sSearch]}%')" if (!params[:sSearch].nil?)
      return conditions.join(" AND ")
    else 
      return nil
    end
  end
end
