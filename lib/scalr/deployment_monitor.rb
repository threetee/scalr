# monitor a deployment for a particular role
module Scalr
  class DeploymentMonitor

    attr_accessor :error, :role, :status, :tasks

    def initialize(role, farm_id)
      @farm_id   = farm_id
      @role      = role
      @last_seen = Time.now
      @status    = 'NOT EXECUTED'
      @tasks     = []
    end

    def completed?
      @status == 'COMPLETED'
    end

    def failed?
      @status == 'FAILED'
    end

    def full_status
      failed? ? "#{status}: #{error}" : status
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
      puts "ROLE: #{@role.name}"
      puts Scalr::ResponseObject::DeploymentTaskItem.show_items(@response.content).join("\n")
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

    def to_s
      "Role #{role.name} - #{full_status} (tasks: #{tasks.empty? ? 'none' : tasks.map{|task| task.id}.join('; ')})"
    end
  end
end