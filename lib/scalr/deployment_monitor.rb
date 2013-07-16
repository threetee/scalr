# monitor a deployment for a particular role
module Scalr
  class DeploymentMonitor

    attr_accessor :error, :role, :status, :tasks

    def initialize(role, farm_id, verbose = false)
      @farm_id   = farm_id
      @role      = role
      @last_seen = Time.now
      @status    = 'NOT EXECUTED'
      @tasks     = []
      @verbose   = verbose
    end

    def run(scalr_caller)
      @last_seen = Time.now
      @response = scalr_caller.invoke(farm_role_id: @role.id)
      unless ! @response.nil? && @response.success?
        @status = 'FAILED'
        @error = @response.nil? ? 'Input validation error' : @response.error
        return
      end
      @status = 'EXECUTED'

      assign_tasks(@response.content)
      if @verbose
        puts "ROLE: #{@role.name}"
        puts Scalr::ResponseObject::DeploymentTaskItem.show_items(@response.content).join("\n")
      end
    end


    def assign_tasks(tasks)
      @tasks = tasks
    end

    def check_system_logs
      scalr_logs_after_last_seen(:logs_list)
    end

    def check_script_logs
      scalr_logs_after_last_seen(:script_logs_list)
    end

    def deployed?
      @status == 'DEPLOYED'
    end

    # this monitor has finished, whether it's completed or failed
    def done?
      deployed? || failed?
    end

    def failed?
      @status == 'FAILED'
    end

    def full_status
      failed? ? "#{status}: #{error}" : status
    end

    def name
      @role.name
    end

    def poll
      return if done?

      system_logs = check_system_logs
      script_logs = check_script_logs
      has_logs = system_logs.size > 0 || script_logs.size > 0

      if refresh_status
        puts "  #{name}: #{status} - #{servers_status.join(' ')}" if @verbose
      end

      if has_logs
        (@verbose || failed?) && puts(to_s)
        show_logs(system_logs, script_logs)
      end

      print '.' unless has_logs || @verbose
    end

    # status will change to one of DEPLOYED|DEPLOYING|FAILED|PENDING
    # iff all the tasks have the same status
    # returns: true if status changed, false if not
    def refresh_status
      @tasks.each do |task|
        @task_refresher ||= Scalr::Caller.new(:dm_deployment_task_get_status)
        response = @task_refresher.invoke(deployment_task_id: task.id)
        next unless response
        task.status = response.content
      end
      previous_status = @status
      @status = 'DEPLOYED'  if @tasks.all? {|task| task.deployed?}
      @status = 'DEPLOYING' if @tasks.all? {|task| task.deploying?}
      @status = 'FAILED'    if @tasks.all? {|task| task.failed?}
      @status = 'PENDING'   if @tasks.all? {|task| task.pending?}
      previous_status == @status
    end

    def servers_status
      @tasks.map {|task| "[Server: #{task.server_short}: #{task.status}]"}
    end

    def show_logs(system_logs, script_logs)
      (system_logs + script_logs).each {|log| puts log.to_s}
    end

    def summary_server_status
      tasks.
          group_by{|task| task.status}.
          map{|status, tasks| "#{status}: #{tasks.length}"}
    end

    def to_s
      "Role #{role.name} - #{full_status} (tasks: #{tasks.empty? ? 'none' : tasks.map{|task| task.id}.join('; ')})"
    end

  private

    def scalr_logs_after_last_seen(action_name)
      log_caller = Scalr::Caller.new(action_name)
      logs = @tasks.flat_map do |task|
        response = log_caller.invoke(farm_id: @farm_id, server_id: task.server_id)
        if response && response.success?
          response.content.find_all {|log_item| log_item.after?(@last_seen)}
        else
          []
        end
      end
      @last_seen = Time.now
      logs.compact
    end

  end
end