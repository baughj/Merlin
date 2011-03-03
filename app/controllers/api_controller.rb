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

class ApiController < ApplicationController

  def getInstances
    @instances = Instance.all
    render :template => 'api/getInstances' and return
  end

  def getInstanceDetailPane
    if params[:id]
      @instance = Instance.find_by_instance_id(params[:id])
      render :template => 'api/getInstanceDetailPane' and return
    else
      render :template => 'api/error' and return
    end
  end

  def getAllObjects
  end

  def getObjectDetails
  end

  def getVolumes

  end

  def getSnapshots
  end


  def stopInstance
  end


  def terminateInstance
  end


  def startInstance
  end

  def launchInstance
  end

  

end
