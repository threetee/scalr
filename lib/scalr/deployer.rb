# deploy an application to all roles, doing monitoring of all...
require 'scalr/deployment_monitor'

module Scalr
  class Deployer

    SLEEP_SECONDS = 6

    def initialize(options)
      puts "Initializing deployer with options: #{options.inspect}"
      @farm_id        = options[:farm_id]
      @application_id = options[:application_id]
      @remote_path    = options[:remote_path]
      @monitors       = []
    end

    def execute
      initialize_monitors
      puts "Executing #{@monitors.length} monitors:"

      deploy_caller = Scalr::Caller.new(:dm_application_deploy)
      deploy_caller.partial_options(application_id: @application_id, farm_id: @farm_id,
                                    remote_path: @remote_path)
      @monitors.each do |monitor|
        monitor.run(deploy_caller)
        puts "...executed monitor: #{monitor}"
      end

      poll_monitors
    end

    def initialize_monitors
      # TODO: check farm to ensure it's not a DB farm, which we'll forbid
      role_response = Scalr::Caller.new(:farm_get_details).invoke(farm_id: @farm_id)
      unless role_response && role_response.success?
        error = role_response.nil? ? 'Validation error' : role_response.error
        raise "FAILED to fetch roles for farm: #{error}"
      end

      @monitors = role_response.content.map do |role|
        Scalr::DeploymentMonitor.new(role, @farm_id)
      end

      puts "Created #{@monitors.length} monitors:"
      @monitors.each {|monitor| puts "  #{monitor.to_s}"}
    end

    def poll_monitors
      # loop through monitors every n seconds and check status
      (1..20).each do |count|
        slept_for = sleep(SLEEP_SECONDS)
        puts "#{count}. => slept for #{slept_for} seconds"
        @monitors.each do |monitor|
          system_logs = monitor.check_system_logs
          script_logs = monitor.check_script_logs
          next if system_logs.empty? && script_logs.empty?
          puts "#{monitor.to_s} - System: #{system_logs.length} - Script: #{script_logs.length}"
          (system_logs + script_logs).each {|log| puts log.to_s}
        end
      end
    end
  end
end