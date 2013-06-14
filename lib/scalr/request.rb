require 'uri'
require 'hmac'
require 'hmac-sha2'
require 'base64'
require 'net/https' 
require 'net/http'

module Scalr
  class Request
    class ScalrError < RuntimeError; end
    class InvalidInputError < ScalrError; end
    
    ACTIONS = {
      :bundle_task_get_status => {:name => 'BundleTaskGetStatus', :inputs => {:bundle_task_id => true}},
      :dns_zone_create => {:name => 'DNSZoneCreate', :inputs => {:domain_name => true, :farm_id => false, :farm_role_id => false}},
      :dns_zone_record_add => {:name => 'DNSZoneRecordAdd', :inputs => {:zone_name => true, :type => true, :ttl => true, :name => true, :value => true, :priority => false, :weight => false, :port => false}},
      :dns_zone_record_remove => {:name => 'DNSZoneRecordRemove', :inputs => {:zone_name => true, :record_id => true}},
      :dns_zone_records_list => {:name => 'DNSZoneRecordsList', :inputs => {:zone_name => true}},
      :dns_zones_list => {:name => 'DNSZonesList', :inputs => {}},
      :events_list => {:name => 'EventsList', :inputs => {:farm_id => true, :start_from => false, :records_limit => false}},
      :farm_get_details => {:name => 'FarmGetDetails', :inputs => {:farm_id => true}},
      :farm_get_stats => {:name => 'FarmGetStats', :inputs => {:farm_id => true, :date => false}},
      :farm_launch => {:name => 'FarmLaunch', :inputs => {:farm_id => true}},
      :farm_terminate => {:name => 'FarmTerminate', :inputs => {:farm_id => true, :keep_ebs => true, :keep_eip => false, :keep_dns_zone => false}},
      :farms_list => {:name => 'FarmsList', :inputs => {}},
      :global_variables_list => {:name => 'GlobalVariablesList', :inputs => {:farm_id => false, :role_id => false, :farm_role_id => false, :server_id => false}},
      :logs_list => {:name => 'LogsList', :inputs => {:farm_id => true, :server_id => true, :start_from => false, :records_limit => false}},
      :roles_list => {:name => 'RolesList', :inputs => {:platform => false, :name => false, :prefix => false, :image_id => false}},
      :script_execute => {:name => 'ScriptExecute', :inputs => {:farm_role_id => false, :server_id => false, :farm_id => true, :script_id => true, :timeout => true, :async => true, :revision => false, :config_variables => false}},
      :script_get_details => {:name => 'ScriptGetDetails', :inputs => {:script_id => true}},
      :scripts_list => {:name => 'ScriptsList', :inputs => {}},
      :server_image_create => {:name => 'ServerImageCreate', :inputs => {:server_id => true, :role_name => true}},
      :server_launch => {:name => 'ServerLaunch', :inputs => {:farm_role_id => true}},
      :server_reboot => {:name => 'ServerReboot', :inputs => {:server_id => true}},
      :server_terminate => {:name => 'ServerTerminate', :inputs => {:server_id => true, :decrease_min_instances_setting => false}},
      :statistics_get_graph_url => {:name => 'StatisticsGetGraphURL', :inputs => {:object_type => true, :object_id => true, :watcher_name => true, :graph_type => true}}
    }

    INPUTS = {
      :async => 'Async',
      :bundle_task_id => 'BundleTaskID',
      :config_variables => 'ConfigVariables',
      :date => 'Date',
      :decrease_min_instances_setting => 'DecreaseMinInstancesSetting',
      :domain_name => 'DomainName',
      :farm_id => 'FarmID',
      :farm_role_id => 'FarmRoleID',
      :graph_type => 'GraphType',
      :image_id => 'ImageID',
      :keep_dns_zone => 'KeepDNSZone',
      :keep_ebs => 'KeepEBS',
      :keep_eip => 'KeepEIP',
      :key => 'Key',
      :name => 'Name',
      :object_id => 'ObjectID',
      :object_type => 'ObjectType',
      :platform => 'Platform',
      :port => 'Port',
      :prefix => 'Prefix',
      :priority => 'Priority',
      :record_id => 'RecordID',
      :records_limit => 'RecordsLimit',
      :revision => 'Revision',
      :role_name => 'RoleName',
      :script_id => 'ScriptID',
      :server_id => 'ServerID',
      :start_from => 'StartFrom',
      :timeout => 'Timeout',
      :ttl => 'TTL',
      :type => 'Type',
      :value => 'Value',
      :watcher_name => 'WatcherName',
      :weight => 'Weight',
      :zone_name => 'ZoneName'      
    }
    
    attr_accessor :inputs, :endpoint, :access_key, :signature
    
    def initialize(action, endpoint, key_id, access_key, version, *arguments)
      set_inputs(action, arguments.flatten.first)
      @inputs.merge!('Action' => ACTIONS[action.to_sym][:name], 'KeyID' => key_id, 'Version' => version, 'Timestamp' => Time.now.utc.iso8601)
      @endpoint = endpoint
      @access_key = access_key
    end
    
    def process!
      set_signature!
      http = Net::HTTP.new(@endpoint, 443)
      http.set_debug_output(Scalr.debug)  if Scalr.debug
      http.use_ssl = true
      response = http.get("/?" + query_string + "&Signature=#{@signature}", {})
      return Scalr::Response.new(response, response.body)
    end
    
    private
    
      def set_inputs(action, input_hash)
        input_hash ||= {}
        raise InvalidInputError.new unless input_hash.is_a? Hash
        ACTIONS[action][:inputs].each do |key, value|
          raise InvalidInputError.new("Missing required input: #{key.to_s}") if value and input_hash[key].nil?
        end
        @inputs = {}
        input_hash.each do |key, value|
          raise InvalidInputError.new("Unknown input: #{key.to_s}") if ACTIONS[action][:inputs][key].nil?
          @inputs[INPUTS[key]] = value.to_s
        end
      end
      
      def query_string
        @inputs.sort.collect { |key, value| [URI.escape(key.to_s), URI.escape(value.to_s)].join('=') }.join('&')
      end
      
      def set_signature!
        string_to_sign = query_string.gsub('=','').gsub('&','')
        hmac = HMAC::SHA256.new(@access_key)
        hmac.update(string_to_sign)
        @signature = URI.escape(Base64.encode64(hmac.digest).chomp, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end
      
  end
end