# deploy an application to all roles, doing monitoring of all...
require 'scalr/deployment_monitor'

module Scalr
  class Deployer

    POLL_SLEEP_SECONDS = 10
    MAX_POLL_COUNT = 60

    def initialize(options)
      @farm_id        = options[:farm_id]
      @application_id = options[:application_id]
      @remote_path    = options[:remote_path]
      @verbose        = options[:verbose]
      @monitors       = []
    end

    def execute
      initialize_monitors
      @verbose && puts("Starting #{@monitors.length} monitors...")

      deploy_caller = Scalr::Caller.
                        new(:dm_application_deploy).
                        partial_options(application_id: @application_id,
                                        farm_id: @farm_id,
                                        remote_path: @remote_path)
      @monitors.each do |monitor|
        monitor.start(deploy_caller)
        @verbose && puts("...started monitor: #{monitor}")
      end

      poll_monitors
    end

    def initialize_monitors
      role_response = Scalr::Caller.new(:farm_get_details).invoke(farm_id: @farm_id)
      unless role_response && role_response.success?
        error = role_response.nil? ? 'Validation error' : role_response.error
        raise "FAILED: Cannot fetch roles for farm: #{error}"
      end

      db_roles = role_response.content.find_all {|role| role.name.match(/^PGSQL/)}
      unless db_roles.empty?
        raise "FAILED: Cannot deploy to a database farm. DB roles: #{db_roles.map{|r| r.name}.join(', ')}"
      end

      @monitors = role_response.content.map {|role| Scalr::DeploymentMonitor.new(role, @farm_id, @verbose)}
      @verbose && puts("Deploying to roles: #{@monitors.map {|m| m.name}.join(', ')}")
    end

    # loop through monitors every n seconds and check status
    def poll_monitors
      (1..MAX_POLL_COUNT).each do |count|
        if @monitors.all? {|monitor| monitor.done?}
          show_complete
          break
        end
        @monitors.each{|monitor| monitor.poll}
        @verbose && print("Poll #{count} of #{MAX_POLL_COUNT}: ")
        print @monitors.inject(0) {|sum, monitor| sum + monitor.servers_not_done.length}, ' '
        @verbose && print("servers remain\n")
        sleep(POLL_SLEEP_SECONDS)
      end

      unless @monitors.all? {|monitor| monitor.done?}
        puts "\nTIME OUT.\nSpent #{MAX_POLL_COUNT * POLL_SLEEP_SECONDS} seconds waiting\n" +
             "for the deployment to finish. I can't wait any longer!"
        show_complete
      end
    end

    def show_complete
      all_ok = @monitors.all? {|monitor| monitor.completed?}
      puts "\nCOMPLETE: #{all_ok ? 'All OK - AWESOME' : 'SOME FAILED'}."
      unless all_ok
        @monitors.each do |monitor|
          puts "#{monitor.name}: #{monitor.summarize_server_status.join('; ')}"
          puts monitor.summaries.join("\n")
        end
      end
    end
  end
end