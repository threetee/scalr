module Scalr
  # encapsulates the process for a single server; this includes the lifecycle of a
  # deployment task as well as scanning scripting logs for relevant messages

  # some of the logging we may only process instead of fetch-and-process
  # since the Scalr API doesn't let you
  class ServerDeployment
    attr_reader :log_sink, :name, :status

    def initialize(farm_id, role, server)
      role_alias = Scalr.first_alias('role', role.name) || role.name
      @name = "#{role_alias}.#{server.index}"
      @farm_id = farm_id
      @server = server
      @status = 'NOT EXECUTED'
      @log_sink = Scalr::LogSink.new(@name)
      @last_seen = Time.now
    end

    def completed?; @status == 'completed' end
    def deployed?;  @status == 'deployed'  end
    def deploying?; @status == 'deploying' end
    def done?;      failed? || completed?  end
    def failed?;    @status == 'failed'    end
    def pending?;   @status == 'pending'   end

    def to_s
      "#{@name}: #{@status}"
    end

    def add_log(log)
      @log_sink << log
    end

    def assign_task(task)
      if missing_task?
        @task   = task
        @status = task.status
      else
        raise "Task already assigned to deployment! [Existing: #{@task.to_s}]"
      end
    end

    # TODO: take the raw failures and categorize them into an object
    def failures
      @log_sink.failures.map{|failure| Scalr::ServerFailure.new(@server, failure)}
    end

    def id
      @server.id
    end

    def missing_task?
      @task.nil?
    end

    def refresh
      return false if done?
      previous_status = @task.status
      response = task_refresher.invoke(deployment_task_id: @task.id)
      @task.status = response.content if response
      previous_status == @task.status
    end

    def scan_logs
      return if done?
      [:logs_list, :script_logs_list].each do |log_action|
        log_caller = Scalr::Caller.new(log_action)
        response = log_caller.invoke(farm_id: @farm_id, server_id: @server.id)
        if response && response.success?
          response.content.
              find_all {|log_item| log_item.after?(@last_seen)}.
              each {|log_item| add_log(log_item)}
        end
      end

      @last_seen = Time.now

      # we found the last script, do any analysis here... (or in the log, or in the sink)
      if script_log = @log_sink.config_and_launch_script
        if script_log.success?
          @status = 'completed'
        else
          @status = 'failed'
        end
      end
    end

    def task_refresher
      @task_refresher ||= Scalr::Caller.new(:dm_deployment_task_get_status)
    end

  end
end