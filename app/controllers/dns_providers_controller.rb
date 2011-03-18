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

require 'formtastic'

module Formtastic #:nodoc:
  class SemanticFormBuilder #:nodoc:
    def enum_input(method, options)
      unless options[:collection]
        enum = @object.enums(method.to_sym)
        choices = enum ? enum.select_options : []
        options[:collection] = choices
      end
      if (value = @object.__send__(method.to_sym))
        options[:selected] ||= value.to_s
      else
        options[:include_blank] ||= true
      end
      select_input(method, options)
    end
  end
end

class DnsProvidersController < ApplicationController

  def new
    @dnsprovider = DnsProvider.new
  end

  def create
    @dnsprovider = DnsProvider.new(params[:dns_provider])
    if @dnsprovider.save
      flash[:notice] = "DNS provider created successfully."
      @dnsprovider.status_message = "OK"
      @dnsprovider.save
      render :action => "index"
    else
      render :action => "new"
    end
  end

  def edit
  end

  def delete
  end

  def index
  end

end
