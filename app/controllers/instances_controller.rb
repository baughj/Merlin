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

require "erb"
require "base64"

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

  def new 
    @instance = Instance.new
    @instance.volume.build
  end

  def index
    respond_to do |format|
      format.json do 
        logger.debug('Rendering JSON instance list')
        json_ret = {}
        json_ret['sEcho'] = params[:sEcho]
        json_ret['iTotalRecords'] = total_objects(params)
        json_ret['iTotalDisplayRecords'] = total_objects(params)
        aaData = []
        current_objects(params).each do |i|
          aaData.push([render_to_string(:partial => "status_image", 
                                        :object => i),
                       i.hostname, i.instance_id, 
                       i.vm_type.nil? ? "unknown" : i.vm_type.name,
                       i.security_groups.map { |k| k.name },
                       i.key_pair.nil? ? "Unknown" : i.key_pair.name,
                       i.status_message])
        end
        json_ret['aaData'] = aaData
        render :json => json_ret.to_json
      end
      format.html do 
        render :template => "merlin/index-new.erb" and return
      end
    end
  end

  def attachstorage 

    check_token

    if @instance.running?
      @instance.volume.each do |v|
        if !v.request_attachment
          api_render_error("Error: Volume #{v.volume_id} reported #{v.get_attachment_error}")
        end
      end
      attachments = @instance.volume.map { |v| v.volume_id}.to_sentence
      api_render_success("Volumes #{attachments} were successfully attached.")
    else
      api_render_error("Instance must be in a running state to attach storage to it.")
    end

  def hello

    check_token

    if @instance.running? then
      @instance.status_code = Instance::STATUS['error']
      @instance.status_message = "hello error: Instance requested hello but was not in a pre-provisioned state...?"
      @instance.save
      flash.now[:error] = "Instance status is marked as #{Instance::STATUS_REVERSE[@instance.status_code]} (should be pending/running). Aborting."
      render :template => "api/response" and return
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
    render :template => "api/response" and return

  end


  protected

  def api_render_success(message=nil)
    if message
      flash.now[:notice] = message
    end
    render :template => "api/response" and return
  end

  def api_render_error(message)
    flash.now[:error] = message
    render :template => "api/response" and return
  end

  def check_token
    # Do a couple of sanity checks first

    @instance = Instance.find_by_instance_id(params[:id])

    if @instance.nil?
      flash.now[:error] = "A valid instance ID must be specified: #{params[:id]} was not found"
      render :template => "api/response" and return
    end

    if params[:access_token].nil? or @instance.access_token != params[:access_token]
      flash.now[:error] = "Invalid access token"
      render :template => "api/response" and return
    end
  end

  def current_objects(params={})
    current_page = (params[:iDisplayStart].to_i/params[:iDisplayLength].to_i rescue 0)+1
    @current_objects = Instance.paginate :page => current_page, :include => [:vm_type, :security_groups, :key_pair],
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
      return "instances.hostname"
    when 2
      return "instances.instance_id"
    when 3
      return "vm_types.name"
    when 4
      return "security_groups.name"
    when 5
      return "key_pairs.name"
    when 6
      return "instances.status_message"
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
