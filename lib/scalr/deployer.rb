# deploy an application to all roles, doing monitoring of all...
require 'scalr/deployment_monitor'

module Scalr
  class Deployer

    POLL_SLEEP_SECONDS = 10
    MAX_POLL_COUNT = 60

    attr_accessor :deployment_key

    def initialize(options)
      @farm_id          = options[:farm_id]
      @verbose          = options[:verbose]
      @hard_restart     = options[:hard]

      @application_id   = options[:application_id]
      @remote_path      = options[:remote_path]

      @application_name = options[:application_name]
      @new_deploy       = options[:new_deploy]
      @script_id        = options[:script_id]
      @deployment_key   = options[:deployment_key] || SecureRandom.uuid

      @monitors         = []
    end

    def execute
      initialize_monitors
      @verbose && puts("Starting #{@monitors.length} monitors...")

      if @new_deploy
        # execute the script for entire farm, then poll for results
        script_options = {
          farm_id:            @farm_id,
          script_id:          @script_id,
          timeout:            1200,
          config_variables:   {
            restart_on_deploy:  @hard_restart ? 'true' : 'false',
            my_app:             @application_name,
            deployment_key:     deployment_key
          }
        }
        script_result = Scalr::Caller.new(:script_execute).invoke(script_options)
        unless script_result && script_result.success?
          puts 'Script failure, please see logs'
          return
        end
        deploy_caller = nil
      else
        # execute once per role, then poll for results
        deploy_caller = Scalr::Caller
          .new(:dm_application_deploy)
          .partial_options(application_id: @application_id,
                           farm_id:        @farm_id,
                           remote_path:    @remote_path)
        flag_hard_restart if @hard_restart
      end

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

      @monitors = role_response.content.
          find_all {|role| ! role.name.match(/(PGSQL|lb\-nginx|DataLoad)/)}. # no databases or load balancers
          map {|role| Scalr::DeploymentMonitor.new(role, @farm_id, verbose: @verbose, new_deploy: @new_deploy)}

      if @monitors.empty?
        raise 'FAILED: Cannot deploy to a farm with only database roles! ',
              "Available roles: #{role_response.content.map{|r| r.name}.join(', ')}"
      end

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
        puts "\nTIME OUT.\nSpent #{MAX_POLL_COUNT * POLL_SLEEP_SECONDS} seconds waiting for the deployment\n" +
             "to finish. I can't wait any longer!"
        show_complete
      end
    end

    def show_complete
      all_ok = @monitors.all? {|monitor| monitor.completed?}
      puts "\nCOMPLETE: #{all_ok ? 'All OK - AWESOME' : 'SOME FAILED'}.\n"
      unless all_ok
        @monitors.each do |monitor|
          puts '========================================',
               "#{monitor.name}: #{monitor.summarize_server_status.join('; ')}",
               monitor.summaries.join("\n")
        end
      end
    end

  private
    # the next time we need to read/write from/to redis move this into a separate object...
    def flag_hard_restart
      redis_path = `which redis-cli`.chomp
      if redis_path.empty?
        $stderr.puts 'SKIP: Cannot mark this deployment as a hard restart because "redis-cli" not available. ',
                     'Once the deployment is complete you can do a manual hard restart with:',
                     "   $ ttmscalr restart all -f #{@farm_id}"
        return 'SKIP'
      end
      redis_url = URI.parse(Scalr::Caller.variable_value('TTM_REDIS_URL', farm_id: @farm_id))

      # hardcoded, ignore the value in the URL b/c that's only valid within EC2
      host =  'proxy2.openredis.com'

      port = redis_url.port
      password = redis_url.password

      command = "-h #{host} -p #{port} -a #{password} SET SCALR-ADMIN:DEPLOY:HARD:#{@farm_id} TRUE EX 300"
      @verbose && puts("Marking deployment as hard restart with: #{redis_path} #{command}...")
      result = `#{redis_path} #{command}`
      @verbose && puts("...results: #{result}")
      result # if it works this is 'OK'
    end
  end
end
