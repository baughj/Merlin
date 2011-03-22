require 'ultradns4r'

module MerlinDnsConnector
  class MerlinUltraDnsConnector

    # This won't work. At all. It needs to be refactored.

    def create_record(hostname, ip_address, zone, commit=true)

      begin_transaction

      parts = hostname.split('.')

      if parts.length > 1:
          hostname = "%s.%s" 
      end

      if not hostname.end_with?('.')
        hostname = '%s.' % hostname
      end

      rr_hash = {'transactionID' => @transaction_id,
        'resourceRecord' => {
          'sch:InfoValues' => '',
          :attributes! => {
            'sch:InfoValues' => get_infovalues([ip_address])
          }
        },
        :attributes! => {
          'resourceRecord' => {
            'ZoneName' => APP_CONFIG[:ultrazone],
            'DName' => hostname,
            'TTL' => APP_CONFIG[:ultranew_record_ttl],
            'Type' => UltraDns::Client.get_rr_type_id('A')
          }
        }
      }

      Rails.logger.fatal rr_hash
      @connector.soap_call('create_resource_record!', rr_hash)

      if @connector.error
        Rails.logger.fatal 'Failed to create record (Zone="%s", Name="%s", TTL="%s", Type=A, Data="%s")' %
          [APP_CONFIG[:ultrazone], hostname, APP_CONFIG[:ultranew_record_ttl], ip_address]
        return false
      end

      if commit
        end_transaction
      end
    end

    def delete_record(hostname)
      # First, see if the record exists

      if not @connector then
        connect_api
      end

      if not hostname.end_with?('.')
        hostname = '%s.' % hostname
      end

      begin_transaction

      Rails.logger.info('[UltraDNS] Deleting hostname %s' % hostname)

      resp = @connector.soap_call('get_resource_records_of_dname_by_type!',
                                  {'zoneName' => APP_CONFIG[:ultrazone],
                                    'hostName' => hostname,
                                    'rrType' => UltraDns::Client.get_rr_type_id('A')})

      record = resp.to_hash[:get_resource_records_of_d_name_by_type_response][:resource_record_list][:resource_record]

      if record
        guid = record[:guid]
      else
        @api_error = "Entry %s not found" % hostname
        raise DNSRecordNotFound
      end

      resp = @connector.soap_call('delete_resource_record!',
                                      {'transactionID' => @transaction_id,
                                        'guid' => guid})
      if @connector.error
        Rails.logger.error "[UltraDNS] Error deleting resource record for %s: %s" % [hostname, @connector.error]
        @error = @connector.error
        return false
      end

      end_transaction
    end
  end

  protected

  def begin_transaction
    if not @connector then
      raise RuntimeError, "You have to connect first."
    end

    if @transaction_id && @transaction_count < 10
      return true
    elsif @transaction_count && @transaction_count >= 10
      if not end_transaction
        return false
      end
      # This connection can be reused
      return true
    end

    resp = @connector.soap_call('start_transaction!')

    if @connector.error
      Rails.logger.error "[UltraDNS] Error getting transaction id: " + @connector.error
      @error = @connector.error
      return false
    else
      @transaction_id = resp.to_hash[:start_transaction_response][:transaction_id]
      @transaction_count = 0
    end

    Rails.logger.info "[UltraDNS] Starting transaction %s" % @transaction_id
  end

  def end_transaction
    Rails.logger.info "[UltraDNS] Committing transaction..."

    if not @connector or not @transaction_id
      return false
    end

    @connector.soap_call('commit_transaction!', {"transactionID" => @transaction_id})

    if @connector.error
      Rails.logger.error "[UltraDNS] Failed to commit transaction %s: %s" % [@transaction_id,
                                                                             @connector.error]
      @connector.soap_call('rollback_transaction!', {"transactionID" => @transaction_id})
      if @connector.error
        Rails.logger.error "[UltraDNS] Failed to rollback uncommittable transaction %s: %s" % [@transaction_id,
                                                                                               @connector.error]
      end
      @transaction_id = nil
      return false
    end
    Rails.logger.info "[UltraDNS] Committed transaction with ID %s" % @transaction_id
    @transaction_id = nil
    return true
  end

  def get_infovalues(data)
    infovalues = {}
    data.each do |value|
      infovalues['Info' + (infovalues.length + 1).to_s + 'Value'] = value
    end
    return infovalues
  end

  class MerlinBindConnector

    attr_accessor :server, :zone, :tsig_keyname, :tsig_key

    # Feel free to hack this to make it dynamic.
    DEFAULT_ALGORITHM = 'HMAC-SHA1'

    def initialize(options)
      {:server => nil,
        :zone => nil,
        :tsig_keyname => nil,
        :tsig_key => nil}.merge(options)

      [:server, :zone, :tsig_keyname, :tsig_key].each do |o|
        if !o.nil?
          self.instance_variable_set "@#{o.to_s}", options[o]
        else
          raise ArgumentError, "Required argument #{o} was not specified."
        end
      end

    end

    def create_alias(hostname, target, ttl)
      prepare_update
      @update.add(hostname, Dnsruby::Types.A, ttl, target)
      @res.send_message(@update)
    end

    def create_cname(hostname, target, ttl)
      prepare_update
      @update.add(hostname, Dnsruby::Types.CNAME, ttl, target)
      @res.send_message(@update)
    end

    # Warning: At the moment, this will delete *all* entries. This will change in the future.
    def delete_record(hostname)
      prepare_update
      @update.delete(hostname)
      @res.send_message(@update)
    end

    private

    def generate_tsig
      return Dnsruby::RR.new_from_hash(:type => Dnsruby::Types.TSIG,
                                       :klass => Dnsruby::Classes.ANY,
                                       :name => @tsig_keyname,
                                       :key => @tsig_key,
                                       :algorithm => DEFAULT_ALGORITHM)
    end

    def prepare_update
      if @res.nil?
        @res = Dnsruby::Resolver.new(:nameserver => server)
        @res.tsig = generate_tsig
      end
      if @update.nil?
        @update = Dnsruby::Update.new(zone)
      end
    end

  end
end
