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

class CloudType < ActiveRecord::Base
  has_many :cloud
  has_many :vm_type

  def paravirtualized?
    # Yes for AWS and Xen+Eucalyptus, no for KVM+Eucalyptus
    return paravirtualized
  end

  def eucalyptus?
    return name == 'eucalyptus'
  end

  def aws?
    return name == 'aws'
  end

  def multiple_volumes?
    return support_multiple_ebs_volumes
  end

end
