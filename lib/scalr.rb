require 'net/https' 
require 'net/http'

module Scalr
  
  mattr_accessor :endpoint
  @@endpoint = "api.scalr.net"
  
  mattr_accessor :api_key
  @@api_key = nil
  
  mattr_accessor :version
  @@version = "2009-05-07"
  
  ACTIONS = {
    :add_dns_zone_record => {:action => 'AddDNSZoneRecord', :inputs => {:domain_name => true, :type => true, :ttl => true, :key => true, :value => true, :priority => false, :weight => false, :port => false}},
    :execute_script => {:action => 'ExecuteScript', :inputs => {:farm_role_id => false, :instance_id => false, :farm_id => true, :script_id => true, :timeout => true, :async => true, :revision => false, :config_variables => false}},
    :get_events => {:action => 'GetEvents', :inputs => {:farm_id => true, :start_from => false, :records_limit => false}},
    :get_farm_details => {:action => 'GetFarmDetails', :inputs => {:farm_id => true}},
    :get_farm_stats => {:action => 'GetFarmStats', :inputs => {:farm_id => true, :date => false}},
    :get_logs => {:action => 'GetLogs', :inputs => {:farm_id => true, :instance_id => true, :start_from => false, :records_limit => false}},
    :get_script_details => {:action => 'GetScriptDetails', :inputs => {:script_id => true}},
    :launch_farm => {:action => 'LaunchFarm', :inputs => {:farm_id => true}},
    :launch_instance => {:action => 'LaunchInstance', :inputs => {:farm_role_id => true}},
    :list_applications => {:action => 'ListApplications', :inputs => {}},
    :list_dns_zone_records => {:action => 'ListDNSZoneRecords', :inputs => {:domain_name => true}},
    :list_dns_zones => {:action => 'ListDNSZones', :inputs => {}},
    :list_farms => {:action => 'ListFarms', :inputs => {}},
    :list_roles => {:action => 'ListRoles', :inputs => {:region => true, :name => false, :prefix => false, :ami_id => false}},
    :list_scripts => {:action => 'ListScripts', :inputs => {}},
    :reboot_instance => {:action => 'RebootInstance', :inputs => {:farm_id => true, :instance_id => true}},
    :remove_dns_zone_record => {:action => 'RemoveDNSZoneRecord', :inputs => {:domain_name => true, :record_id => true}},
    :terminate_farm => {:action => 'TerminateFarm', :inputs => {:farm_id => true, :keep_ebs => true, :keep_eip => true, :keep_dns_zone => true}},
    :terminate_instance => {:action => 'TerminateInstance', :inputs => {:farm_id => true, :instance_id => true, :keep_eip => true, :decrease_min_instances_setting => false}}
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
  
  class << self
    
    def method_missing(method_id, *arguments)
      if matches_action? method_id
        
      else
        super
      end
    end
    
    private
    
      def matches_action?(method_id)
        ACTIONS.keys.include? method_id.to_sym
      end
    
  end
  
end