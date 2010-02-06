require 'cgi'
require 'hmac'
require 'hmac-sha2'
require 'base64'
require 'net/https' 
require 'net/http'

module Scalr
  module Request
    class ScalrError < RuntimeError; end
    class InvalidInputError < ScalrError; end
    
    
    ACTIONS = {
      :add_dns_zone_record => {:name => 'AddDNSZoneRecord', :inputs => {:domain_name => true, :type => true, :ttl => true, :key => true, :value => true, :priority => false, :weight => false, :port => false}},
      :execute_script => {:name => 'ExecuteScript', :inputs => {:farm_role_id => false, :instance_id => false, :farm_id => true, :script_id => true, :timeout => true, :async => true, :revision => false, :config_variables => false}},
      :get_events => {:name => 'GetEvents', :inputs => {:farm_id => true, :start_from => false, :records_limit => false}},
      :get_farm_details => {:name => 'GetFarmDetails', :inputs => {:farm_id => true}},
      :get_farm_stats => {:name => 'GetFarmStats', :inputs => {:farm_id => true, :date => false}},
      :get_logs => {:name => 'GetLogs', :inputs => {:farm_id => true, :instance_id => true, :start_from => false, :records_limit => false}},
      :get_script_details => {:name => 'GetScriptDetails', :inputs => {:script_id => true}},
      :launch_farm => {:name => 'LaunchFarm', :inputs => {:farm_id => true}},
      :launch_instance => {:name => 'LaunchInstance', :inputs => {:farm_role_id => true}},
      :list_applications => {:name => 'ListApplications', :inputs => {}},
      :list_dns_zone_records => {:name => 'ListDNSZoneRecords', :inputs => {:domain_name => true}},
      :list_dns_zones => {:name => 'ListDNSZones', :inputs => {}},
      :list_farms => {:name => 'ListFarms', :inputs => {}},
      :list_roles => {:name => 'ListRoles', :inputs => {:region => true, :name => false, :prefix => false, :ami_id => false}},
      :list_scripts => {:name => 'ListScripts', :inputs => {}},
      :reboot_instance => {:name => 'RebootInstance', :inputs => {:farm_id => true, :instance_id => true}},
      :remove_dns_zone_record => {:name => 'RemoveDNSZoneRecord', :inputs => {:domain_name => true, :record_id => true}},
      :terminate_farm => {:name => 'TerminateFarm', :inputs => {:farm_id => true, :keep_ebs => true, :keep_eip => true, :keep_dns_zone => true}},
      :terminate_instance => {:name => 'TerminateInstance', :inputs => {:farm_id => true, :instance_id => true, :keep_eip => true, :decrease_min_instances_setting => false}}
    }

    INPUTS = {
      :domain_name => 'DomainName',
      :type => 'Type',
      :ttl => 'TTL',
      :key => 'Key',
      :value => 'Value',
      :priority => 'Priority',
      :weight => 'Weight',
      :port => 'Port',
      :farm_role_id => 'FarmRoleID',
      :instance_id => 'InstanceID',
      :farm_id => 'FarmID',
      :script_id => 'ScriptID',
      :timeout => 'Timeout',
      :async => 'Async',
      :revision => 'Revision',
      :config_variables => 'ConfigVariables',
      :start_from => 'StartFrom',
      :records_limit => 'RecordsLimit',
      :date => 'Date',
      :domain_name => 'DomainName',
      :region => 'Region',
      :name => 'Name',
      :prefix => 'Prefix',
      :ami_id => 'AmiID',
      :record_id => 'RecordID',
      :keep_ebs => 'KeepEBS',
      :keep_eip => 'KeepEIP',
      :keep_dns_zone => 'KeepDNSZone',
      :decrease_min_instances_setting => 'DecreaseMinInstancesSetting'
    }
    
    def initialize(action, endpoint, key_id, access_key, version, *arguments)
      set_inputs(action, arguments)
      @inputs.merge!('Action' => ACTIONS[action.to_sym][:name], 'KeyID' => key_id, 'Version' => version, 'TimeStamp' => Time.now.iso8601)
      @endpoint = endpoint
      @access_key = access_key
    end
    
    def process!
      set_signature!
      http = Net::HTTP.new(@endpoint, 443)
      http.use_ssl = true
      response, data = http.get("/?" + query_string, nil)
      return Scalr::Response.new(response, data)
    end
    
    private 
    
      def set_inputs(action, *arguments)
        raise InvalidInputError.new unless arguments.is_a? Hash
        ACTIONS[action][:inputs].each do |key, value|
          raise InvalidInputError.new("Missing required input: #{key.to_s}") if value and arguments[key].nil?
        end
        @inputs = {}
        arguments.each do |key, value|
          raise InvalidInputError.new("Unknown input: #{key.to_s}") if ACTIONS[@action][:inputs][key].nil?
          @inputs[INPUTS[key]] = value
        end
      end
      
      def query_string
        @inputs.sort.collect { |key, value| [CGI.escape(key.to_s), CGI.escape(value.to_s)].join('=') }.join('&')
      end
      
      def set_signature!
        string_to_sign = query_string.gsub('=','').gsub('&','')
        hmac = HMAC::SHA256.new(@access_key)
        hmac.update(string_to_sign)
        @inputs['Signature'] = Base64.encode64(hmac.digest).chomp
      end
      
  end
end