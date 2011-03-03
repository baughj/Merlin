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

  def dns_connect_api
    begin
      @dns_connector = UltraDns::Client.new(APP_CONFIG[:ultradns_user],
                                        APP_CONFIG[:ultradns_password])
      @transaction_count = 0
    rescue Exception => exc
      Rails.logger.error "[UltraDNS] Error initiating API connection: " + exc
      @dns_error = exc
      return false
    end
  end

  def dns_begin_transaction
    if not @dns_connector then
      dns_connect_api
    end

    if @transaction_id && @transaction_count < 10
      return true
    elsif @transaction_count && @transaction_count >= 10
      if not dns_end_transaction
        return false
      end
      # This connection can be reused
      return true
    end

    resp = @dns_connector.soap_call('start_transaction!')

    if @dns_connector.error
      Rails.logger.error "[UltraDNS] Error getting transaction id: " + @dns_connector.error
      @dns_error = @dns_connector.error
      return false
    else
      @transaction_id = resp.to_hash[:start_transaction_response][:transaction_id]
      @transaction_count = 0
    end

    Rails.logger.info "[UltraDNS] Starting transaction %s" % @transaction_id
  end

  def dns_end_transaction
    Rails.logger.info "[UltraDNS] Committing transaction..."

    if not @dns_connector or not @transaction_id
      return false
    end

    @dns_connector.soap_call('commit_transaction!', {"transactionID" => @transaction_id})

    if @dns_connector.error
      Rails.logger.error "[UltraDNS] Failed to commit transaction %s: %s" % [@transaction_id,
                                                                  @dns_connector.error]
      @dns_connector.soap_call('rollback_transaction!', {"transactionID" => @transaction_id})
      if @dns_connector.error
        Rails.logger.error "[UltraDNS] Failed to rollback uncommittable transaction %s: %s" % [@transaction_id,
                                                                                               @dns_connector.error]
      end
      @transaction_id = nil
      return false
    end

    Rails.logger.info "[UltraDNS] Committed transaction with ID %s" % @transaction_id
    @transaction_id = nil
    return true
  end

  def dns_get_infovalues(data)
    infovalues = {}
    data.each do |value|
      infovalues['Info' + (infovalues.length + 1).to_s + 'Value'] = value
    end

    return infovalues
  end

  def dns_create_record(hostname, ip_address, commit)
    if not @dns_connector then
      dns_connect_api
    end

    dns_begin_transaction

    parts = hostname.split('.')

    if parts.length > 1:
        # For right now we cheat since everything isn't delegated to udns
        hostname = "%s.%s" % [parts[0], APP_CONFIG[:ultradns_zone]]
    end
    if not hostname.end_with?('.')
      hostname = '%s.' % hostname
    end

    rr_hash = {'transactionID' => @transaction_id,
      'resourceRecord' => {
        'sch:InfoValues' => '',
        :attributes! => {
          'sch:InfoValues' => dns_get_infovalues([ip_address])
        }
      },
      :attributes! => {
        'resourceRecord' => {
          'ZoneName' => APP_CONFIG[:ultradns_zone],
          'DName' => hostname,
          'TTL' => APP_CONFIG[:ultradns_new_record_ttl],
          'Type' => UltraDns::Client.get_rr_type_id('A')
        }
      }
    }
    Rails.logger.fatal rr_hash
    @dns_connector.soap_call('create_resource_record!', rr_hash)

    if @dns_connector.error
      Rails.logger.fatal 'Failed to create record (Zone="%s", Name="%s", TTL="%s", Type=A, Data="%s")' %
        [APP_CONFIG[:ultradns_zone], hostname, APP_CONFIG[:ultradns_new_record_ttl], ip_address]
      return false
    end

    if commit
      dns_end_transaction
    end
  end

  def dns_delete_record(hostname)
    # First, see if the record exists

    if not @dns_connector then
      dns_connect_api
    end

    if not hostname.end_with?('.')
      hostname = '%s.' % hostname
    end

    dns_begin_transaction

    Rails.logger.info('[UltraDNS] Deleting hostname %s' % hostname)

    resp = @dns_connector.soap_call('get_resource_records_of_dname_by_type!', 
                                {'zoneName' => APP_CONFIG[:ultradns_zone],
                                  'hostName' => hostname,
                                  'rrType' => UltraDns::Client.get_rr_type_id('A')})
    

    record = resp.to_hash[:get_resource_records_of_d_name_by_type_response][:resource_record_list][:resource_record]

    if record
      guid = record[:guid]
    else
      @api_error = "Entry %s not found" % hostname
      raise DNSRecordNotFound
    end

    resp = @dns_connector.soap_call('delete_resource_record!',
                                {'transactionID' => @transaction_id,
                                  'guid' => guid})
    if @dns_connector.error
      Rails.logger.error "[UltraDNS] Error deleting resource record for %s: %s" % [hostname, @dns_connector.error]
      @dns_error = @dns_connector.error
      return false
    end

    dns_end_transaction
  end
end
