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

class CloudsController < ApplicationController

  include ActiveMessaging::MessageSender

  def create
    # Send a message that a cloud needs to be added to Merlin. We don't do
    # any error checking; that is done by the message consumer.
    payload = { :this_is_a_test => 'yes it is'}
    publish :cloud_added, payload.to_json
  end

  def get_zones_select
  end

  def get_instance_types_select
  end

  def get_vm_types_select
  end

  def get_key_pairs_select
  end

  def get_security_groups_select
  end

  def add_cloud
    publishes_to :cloud_added

    # Adds a cloud to the system, which triggers a message to perform some
    # discovery to find available availability zones, pubkeys, etc.
  end

  def display_clouds
    # Displays the clouds that Merlin knows about.
  end

  def refresh_cloud
    # "Rediscover" all the active elements of a cloud. This should be used with care
    # and is only really needed if multiple management tools are used, or if cloud
    # objects are instantiated without using Merlin (i.e. command line tools or otherwise)

  end

end
