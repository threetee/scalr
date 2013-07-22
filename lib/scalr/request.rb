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

    # Each entry describes an API call we can consume.
    #  - :inputs - describes the data we can/must send
    #  - :outputs - describes some shortcuts for the XML consumed; we'll pop the transactionid into the
    #               response object, then assign the value out of the path-like reference. Most of the
    #               references describe either a single value (e.g., a status or return value) or a
    #               list of records
    #
    # Some examples:
    #
    # 1. :outputs => { :path => 'BundleTaskStatus' }
    #
    #  <BundleTaskGetStatusResponse>
    #    <TransactionID>38cb90b8-c44a-42a4-a24a-c7f19a33de2c</TransactionID>
    #    <BundleTaskStatus>creating-role</BundleTaskStatus>
    #  </BundleTaskGetStatusResponse>
    #
    # response.content => 'creating-role'
    #
    # 2. :outputs => { :path => 'farmset@item' }
    #
    # <ListFarmsResponse>
    #   <TransactionID>4df7f431-927a-43e3-8ccf-bec323f18f9a</TransactionID>
    #   <FarmSet>
    #     <Item>
    #       <ID>123</ID>
    #       <Name>test-farm-1</Name>
    #       <Comments/>
    #       <Status>0</Status>
    #     </Item>
    #     <Item>
    #       <ID>321</ID>
    #       <Name>test-farm-2</Name>
    #       <Comments/>
    #       <Status>1</Status>
    #     </Item>
    #   </FarmSet>
    # </ListFarmsResponse>
    #
    # response.content => [{id: '123', name: 'test-farm-1', comments: nil, status: '0' },
    #                      {id: '321', name: 'test-farm-2', comments: nil, status: '1' }]

    V200 = '2.0.0'
    V210 = '2.1.0'
    V220 = '2.2.0'
    V230 = '2.3.0'

    ACTIONS = {
      :apache_vhost_create => {
          :name => 'ApacheVhostCreate', :version => V210,
          :inputs => {:domain_name => true, :farm_id => true, :farm_role_id => true, :document_root_dir => true,
                      :enable_ssl => true, :ssl_private_key => false, :ssl_certificate => false},
          :outputs => { :path => 'result' }
      },
      :apache_vhosts_list  => {
          :name => 'ApacheVhostsList', :version => V210,
          :inputs => {},
          :outputs => { :path => 'apachevhostsset@item' }
      },
      :bundle_task_get_status => {
          :name => 'BundleTaskGetStatus', :version => V200,
          :inputs => {:bundle_task_id => true},
          :outputs => { :path => 'bundletaskstatus' }
      },
      :dm_application_create => {
        :name => 'DmApplicationCreate', :version => V230,
        :inputs => {:name => true, :source_id => true},
        :outputs => { :path => 'applicationid' }
      },
      :dm_application_deploy => {
          :name => 'DmApplicationDeploy', :version => V230,
          :inputs => {:application_id => true, :farm_role_id => true, :remote_path => true},
          :defaults => { :remote_path => '/var/www' },
          :outputs => { :path => 'deploymenttasksset@item', :object => Scalr::ResponseObject::DeploymentTaskItem }
      },
      :dm_applications_list => {
          :name => 'DmApplicationsList', :version => V230,
          :inputs => {},
          :outputs => { :path => 'applicationset@item', :object => Scalr::ResponseObject::Application }
      },
      :dm_deployment_task_get_log => {
          :name => 'DmDeploymentTaskGetLog', :version => V230,
          :inputs => { :deployment_task_id => true },
          :outputs => { :path => 'logset@item', :object => Scalr::ResponseObject::DeploymentTaskLogItem}
      },
      :dm_deployment_task_get_status => {
          :name => 'DmDeploymentTaskGetStatus', :version => V230,
          :inputs => { :deployment_task_id => true },
          :outputs => { :path => 'deploymenttaskstatus' }
      },
      :dm_deployment_tasks_list => {
          :name => 'DmDeploymentTasksList', :version => V230,
          :inputs => { :application_id => false, :farm_role_id => false, :remote_path => false },
          :outputs => { :path => 'deploymenttasksset@item', :object => Scalr::ResponseObject::DeploymentTaskItem }
      },
      :dm_source_create => {
          :name => 'DmSourceCreate', :version => V230,
          :inputs => { :type => true, :url => true},
          :outputs => { :path => :sourceid }
      },
      :dm_sources_list => {
          :name => 'DmSourcesList', :version => V230,
          :inputs => {},
          :outputs => { :path => 'sourceset@item', :object => Scalr::ResponseObject::SourceItem }
      },
      :dns_zone_create => {
          :name => 'DNSZoneCreate', :version => V200,
          :inputs => {:domain_name => true, :farm_id => false, :farm_role_id => false},
          :outputs => { :path => 'result' }
      },
      :dns_zone_record_add => {
          :name => 'DNSZoneRecordAdd', :version => V200,
          :inputs => {:zone_name => true, :type => true, :ttl => true, :name => true, :value => true,
                      :priority => false, :weight => false, :port => false},
          :outputs => { :path => 'result' }
      },
      :dns_zone_record_remove => {
          :name => 'DNSZoneRecordRemove', :version => V200,
          :inputs => {:zone_name => true, :record_id => true},
          :outputs => { :path => 'result' }
      },
      :dns_zone_records_list => {
          :name => 'DNSZoneRecordsList', :version => V200,
          :inputs => {:zone_name => true},
          :outputs => { :path => 'zonerecordset@item' }
      },
      :dns_zones_list => {
          :name => 'DNSZonesList', :version => V200,
          :inputs => {},
          :outputs => { :path => 'dnszoneset@item' }
      },
      :environments_list => {
          :name => 'EnvironmentsList', :version => V230,
          :inputs => {},
          :outputs => { :path => 'environmentset@item' }
      },
      :events_list => {
          :name => 'EventsList', :version => V200,
          :inputs => {:farm_id => true, :start_from => false, :records_limit => false},
          :outputs => { :path => 'eventset@item' }
      },
      :farm_clone => {
          :name => 'FarmClone', :version => V230,
          :inputs => {:farm_id => true},
          :outputs => { :path => 'farmid' }
      },
      :farm_get_details => {
          :name => 'FarmGetDetails', :version => V230,
          :inputs => {:farm_id => true},
          :outputs => { :path => 'farmroleset@item', :object => Scalr::ResponseObject::FarmRole }
      },
      :farm_get_stats => {
          :name => 'FarmGetStats', :version => V200,
          :inputs => {:farm_id => true, :date => false},
          :outputs => { :path => 'statisticsset@item' }
      },
      :farm_launch => {
          :name => 'FarmLaunch', :version => V200,
          :inputs => {:farm_id => true},
          :outputs => { :path => 'result' }
      },
      :farm_terminate => {
          :name => 'FarmTerminate', :version => V200,
          :inputs => {:farm_id => true, :keep_ebs => true, :keep_eip => false, :keep_dns_zone => false},
          :outputs => { :path => 'result' }
      },
      :farms_list => {
          :name => 'FarmsList', :version => V200,
          :inputs => {},
          :outputs => { :path => 'farmset@item', :object => Scalr::ResponseObject::FarmSummary}
      },
      :global_variable_set => {
          :name => 'GlobalVariableSet', :version => V230,
          :inputs => {:farm_id => false, :farm_role_id => false, :param_name => true, :param_value => true},
          :outputs => { :path => 'result' }
      },
      :global_variables_list => {
          :name => 'GlobalVariablesList', :version => V200,
          :inputs => {:farm_id => false, :role_id => false, :farm_role_id => false, :server_id => false},
          :outputs => { :path => 'variableset@item', :object => Scalr::ResponseObject::Variable}
      },
      :logs_list => {
          :name => 'LogsList', :version => V200,
          :inputs => {:farm_id => true, :server_id => false, :start_from => false, :records_limit => false},
          :outputs => { :path => 'logset@item', :object => Scalr::ResponseObject::LogItem }
      },
      :roles_list => {
          :name => 'RolesList', :version => V200,
          :inputs => {:platform => false, :name => false, :prefix => false, :image_id => false},
          :outputs => { :path => 'roleset@item' }
      },
      :script_execute => {
          :name => 'ScriptExecute', :version => V200,
          :inputs => {:farm_role_id => false, :server_id => false, :farm_id => true, :script_id => true,
                      :timeout => true, :async => true, :revision => false, :config_variables => false},
          :defaults => {:timeout => '30', :async => '0', },
          :outputs => { :path => 'result' }
      },
      :script_get_details => {
          :name => 'ScriptGetDetails', :version => V200,
          :inputs => {:script_id => true},
          :outputs => { :path => 'scriptrevisionset@item', :object => Scalr::ResponseObject::Script }
      },
      :script_logs_list => {
          :name => 'ScriptingLogsList', :version => V230,
          :inputs => {:farm_id => true, :server_id => false, :start_from => false, :records_limit => false},
          :outputs => { :path => 'logset@item', :object => Scalr::ResponseObject::ScriptLogItem }
      },
      :scripts_list => {
          :name => 'ScriptsList', :version => V200,
          :inputs => {},
          :outputs => { :path => 'scriptset@item', :object => Scalr::ResponseObject::ScriptSummary }
      },
      :server_image_create => {
          :name => 'ServerImageCreate', :version => V200,
          :inputs => {:server_id => true, :role_name => true},
          :outputs => { :path => 'bundletaskid' }
      },
      :server_launch => {
          :name => 'ServerLaunch', :version => V200,
          :inputs => {:farm_role_id => true, :increase_max_instances => false},
          :outputs => { :path => 'serverid' }
      },
      :server_reboot => {
          :name => 'ServerReboot', :version => V200,
          :inputs => {:server_id => true},
          :outputs => { :path => 'result' }
      },
      :server_terminate => {
          :name => 'ServerTerminate', :version => V200,
          :inputs => {:server_id => true, :decrease_min_instances_setting => false},
          :outputs => { :path => 'result' }
      },
      :statistics_get_graph_url => {
          :name => 'StatisticsGetGraphURL', :version => V200,
          :inputs => {:object_type => true, :object_id => true, :watcher_name => true, :graph_type => true },
          :outputs => { :path => 'graphurl' }
      },
    }

    INPUTS = {
        :application_id                 => 'ApplicationID',
        :async                          => 'Async',
        :bundle_task_id                 => 'BundleTaskID',
        :config_variables               => 'ConfigVariables',
        :date                           => 'Date',
        :decrease_min_instances_setting => 'DecreaseMinInstancesSetting',
        :deployment_task_id             => 'DeploymentTaskID',
        :document_root_dir              => 'DocumentRootDir',
        :domain_name                    => 'DomainName',
        :enable_ssl                     => 'EnableSSL',
        :farm_id                        => 'FarmID',
        :farm_role_id                   => 'FarmRoleID',
        :graph_type                     => 'GraphType',
        :image_id                       => 'ImageID',
        :increase_max_instances         => 'IncreaseMaxInstances',
        :keep_dns_zone                  => 'KeepDNSZone',
        :keep_ebs                       => 'KeepEBS',
        :keep_eip                       => 'KeepEIP',
        :key                            => 'Key',
        :name                           => 'Name',
        :object_id                      => 'ObjectID',
        :object_type                    => 'ObjectType',
        :param_name                     => 'ParamName',
        :param_value                    => 'ParamValue',
        :platform                       => 'Platform',
        :port                           => 'Port',
        :prefix                         => 'Prefix',
        :priority                       => 'Priority',
        :record_id                      => 'RecordID',
        :records_limit                  => 'RecordsLimit',
        :remote_path                    => 'RemotePath',
        :revision                       => 'Revision',
        :role_id                        => 'RoleID',
        :role_name                      => 'RoleName',
        :script_id                      => 'ScriptID',
        :server_id                      => 'ServerID',
        :source_id                      => 'SourceID',
        :ssl_certificate                => 'SSLCertificate',
        :ssl_private_key                => 'SSLPrivateKey',
        :start_from                     => 'StartFrom',
        :timeout                        => 'Timeout',
        :ttl                            => 'TTL',
        :type                           => 'Type',
        :url                            => 'URL',
        :value                          => 'Value',
        :watcher_name                   => 'WatcherName',
        :weight                         => 'Weight',
        :zone_name                      => 'ZoneName'
    }

    def self.action(name)
      ACTIONS[name.to_sym]
    end

    def self.input(name)
      INPUTS[name.to_sym]
    end

    attr_accessor :inputs, :endpoint, :access_key, :signature
    
    def initialize(action, endpoint, key_id, access_key, version, *arguments)
      set_inputs(action, arguments.flatten.first)
      @action_info = ACTIONS[action.to_sym]
      @inputs.merge!('Action' => @action_info[:name], 'KeyID' => key_id, 'Version' => version, 'Timestamp' => Time.now.utc.iso8601)
      @endpoint = endpoint
      @access_key = access_key
    end
    
    def process!
      set_signature!
      http = Net::HTTP.new(@endpoint, 443)
      #http.set_debug_output(Scalr.debug)  if Scalr.debug
      http.use_ssl = true
      url = "/?#{query_string}&Signature=#{@signature}"
      Scalr.debug.puts(url)  if Scalr.debug
      response = http.get(url, {})
      Scalr.debug.puts(response.body)  if Scalr.debug
      Scalr::Response.new(response, response.body, @action_info, @inputs)
    end
    
    private
    
      def set_inputs(action, input_hash)
        input_hash ||= {}
        raise InvalidInputError.new unless input_hash.is_a? Hash

        # assign defaults
        ACTIONS[action][:inputs].each do |key, _|
          next unless input_hash[key].nil? && ACTIONS[action][:defaults] && ACTIONS[action][:defaults][key]
          input_hash[key] = ACTIONS[action][:defaults][key]
        end

        # required item checking
        ACTIONS[action][:inputs].each do |key, required|
          raise InvalidInputError.new("Missing required input: #{key.to_s}") if required and input_hash[key].nil?
        end
        @inputs = {}
        input_hash.each do |key, value|
          raise InvalidInputError.new("Unknown input: #{key.to_s}") if ACTIONS[action][:inputs][key].nil?
          @inputs[INPUTS[key]] = value # remove to_s from here because that serializes hashes weird, we do that in query_string
        end
      end
      
      def query_string
        elements = @inputs.sort.flat_map do |key, value|
          if value.instance_of?(Hash)
            value.map{|child_key, child_value| pair_for_uri("#{key.to_s}[#{child_key.to_s}]", child_value)}
          elsif value.instance_of?(Array)
            value.map {|child_value| pair_for_uri(key, child_value)}
          else
            pair_for_uri(key, value)
          end
        end
        elements.join('&')
      end

      def pair_for_uri(key, value)
        [URI.escape(key.to_s), URI.escape(value.to_s)].join('=')
      end
      
      def set_signature!
        string_to_sign = query_string.gsub('=','').gsub('&','')
        hmac = HMAC::SHA256.new(@access_key)
        hmac.update(string_to_sign)
        @signature = URI.escape(Base64.encode64(hmac.digest).chomp, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end
      
  end
end
