# deploy an application to all roles, doing monitoring of all...
require 'scalr/deployment_monitor'

module Scalr
  class Deployer

    POLL_SLEEP_SECONDS = 6
    MAX_POLL_COUNT = 40

    def initialize(options)
      @farm_id        = options[:farm_id]
      @application_id = options[:application_id]
      @remote_path    = options[:remote_path]
      @verbose        = options[:verbose]
      @monitors       = []
    end

    def execute
      initialize_monitors
      @verbose && puts("Executing #{@monitors.length} monitors:")

      deploy_caller = Scalr::Caller.
                        new(:dm_application_deploy).
                        partial_options(application_id: @application_id,
                                        farm_id: @farm_id,
                                        remote_path: @remote_path)
      @monitors.each do |monitor|
        monitor.run(deploy_caller)
        @verbose && puts("...executed monitor: #{monitor}")
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
        Scalr::DeploymentMonitor.new(role, @farm_id, @verbose)
      end
      puts "Deploying to roles: #{@monitors.map {|m| m.name}.join(', ')}"
    end

    def poll_monitors
      # loop through monitors every n seconds and check status
      (1..MAX_POLL_COUNT).each do |count|
        if @monitors.all? {|monitor| monitor.done?}
          show_complete
          break
        end
        slept_for = sleep(POLL_SLEEP_SECONDS)
        @verbose && puts("#{count} of #{MAX_POLL_COUNT} => slept for #{slept_for} seconds")
        @monitors.each{|monitor| monitor.poll}
      end

      unless @monitors.all? {|monitor| monitor.done?}
        puts "TIME OUT. Spent #{MAX_POLL_COUNT * POLL_SLEEP_SECONDS} seconds waiting for the deployment " +
             "to finish. I canna wait any longer!"
        show_complete
      end
    end

    def show_complete
      all_ok = @monitors.all? {|monitor| monitor.deployed?}
      puts "\nCOMPLETE: #{all_ok ? 'All OK - AWESOME' : 'SOME FAILED'}."
      unless all_ok
        puts '  Count of status by role:'
        @monitors.each{|monitor| puts "  * #{monitor.name}: #{monitor.summary_server_status.join('; ')}"}
      end
    end
  end
end