# monitor a deployment for a particular role
require 'scalr/server_deployment'
require 'scalr/log_sink'

module Scalr
  class DeploymentMonitor

    attr_accessor :error, :role, :status

    def initialize(role, farm_id, options = {})
      @farm_id    = farm_id
      @role       = role
      @new_deploy = options[:new_deploy]
      @servers    = @role.servers_running.map {|server| create_deployment_for(server)}
      @status     = 'NOT EXECUTED'
      @verbose    = options[:verbose]
    end

    def start(deployment_caller)
      unless @new_deploy
        response = deployment_caller.invoke(farm_role_id: @role.id)
        if response.nil? || response.failed?
          @status = 'FAILED'
          @error = response.nil? ? 'Input validation error' : response.error
          return
        end
        assign_tasks(response.content)
      end
      @status = 'STARTED'
      puts "ROLE: #{@role.name}: #{@servers.length} servers" if @verbose
    end

    def poll
      unless done?
        accumulate_logs
        refresh_status
        puts "  #{name}: #{status} [#{servers_status.join('; ')}]" if @verbose
      end
    end

    def completed?; @status == 'completed' end
    def deployed?;  @status == 'deployed'  end
    def deploying?; @status == 'deploying' end
    def done?;      @servers.all? &:done?  end # this monitor is done whenever all of its servers are done
    def failed?;    @status == 'failed'    end
    def pending?;   @status == 'pending'   end

    def full_status
      failed? ? "#{status}: #{error}" : status
    end

    def name
      @role.name
    end

    # status will change to one of DEPLOYED|DEPLOYING|FAILED|PENDING
    # iff all the tasks have the same status; note that this WILL NEVER
    # RETURN TRUE if you're using the new deployment
    # returns: true if any server status changed, false if none did
    def refresh_status
      changed = @servers.any? &:refresh
      [:completed, :deployed, :deploying, :failed, :pending].each do |status_name|
        check = (status_name.to_s + '?').to_sym
        @status = status_name.to_s if @servers.all? {|server_deploy| server_deploy.send(check)}
      end
      changed
    end

    def servers_not_done
      @servers.find_all {|server_deploy| !server_deploy.done?}
    end

    def servers_status
      @servers.group_by{|s| s.status}.map{|status, servers_in_status| "#{status}: #{servers_in_status.length}"}
    end

    def summaries
      context = {farm_id: @farm_id, role: @role}
      @servers.map do |server_deploy|
        server_problems = server_deploy.failures
        if server_problems.empty?
          server_status = server_deploy.done? ? 'OK' : server_deploy.status.upcase
          "#{server_status}: #{server_deploy.name}"
        else
          server_message = "FAIL: #{server_deploy.name}\n"
          server_problems.each do |problem|
            server_message += "** Type: #{problem.descriptive_type}; #{problem.headline_summary}\n"
            server_message += problem.for_display(context).join("\n")
          end
          server_message
        end
      end
    end

    def summarize_server_status
      @servers.
          group_by {|s| s.status}.
          map {|status, server_deploys| "#{status}: #{server_deploys.length}"}
    end

    def to_s
      "Role #{role.name} - #{full_status}"
    end

  private

    def accumulate_logs
      @servers.each {|server_deploy| server_deploy.scan_logs}
    end

    def assign_tasks(tasks)
      tasks.each do |task|
        server_deploy = deployment_for_server(task.server_id)
        unless server_deploy
          puts "WEIRD! Scalr generated a task for which we didn't have a server entry! Task: #{task.to_s}"
          @servers << create_deployment_for(@role.find_server(task.server_id))
        end
        server_deploy.assign_task(task)
      end
      @servers.find_all {|server_deploy| server_deploy.missing_task?}.each do |server_deploy|
        puts "WEIRD! No Scalr task for running server: #{server_deploy.id}"
        @servers.delete(server_deploy)
      end
    end

    def create_deployment_for(server)
      Scalr::ServerDeployment.new(@farm_id, @role, server, new_deploy: @new_deploy)
    end

    def deployment_for_server(server_id)
      @servers.find {|server| server_id == server.id}
    end

    def log_sinks
      @log_sinks ||= Scalr::LogSinks.new(@servers.map &:log_sink)
    end
  end
end
