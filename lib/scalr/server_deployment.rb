module Scalr
  # encapsulates the process for a single server; this includes the lifecycle of a
  # deployment task as well as scanning scripting logs for relevant messages

  # some of the logging we may only process instead of fetch-and-process
  # since the Scalr API doesn't let you
  class ServerDeployment

    # if we poll this many times for logs and don't get any new ones, we'll
    # try to expand our timeframe back to ensure we didn't miss any
    MAX_POLLS_WITHOUT_CHANGE = 10

    attr_reader :log_sink, :name, :status

    def initialize(farm_id, role, server)
      role_alias = Scalr.first_alias('role', role.name) || role.name
      @name = "#{role_alias}.#{server.index}"
      @farm_id = farm_id
      @server = server
      @status = 'NOT EXECUTED'
      @log_sink = Scalr::LogSink.new(@name)
      @last_seen = Time.now
      @scans_without_change = 0
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
          changes = response.content.
              find_all {|log_item| log_item.after?(@last_seen)}.
              map {|log_item| add_log(log_item)}.
              inject(0) {|sum, log_added| sum + log_added}
          @scans_without_change = changes > 0 ? 0 : @scans_without_change + 1
        end
      end

      # if there have been too many scans without a change, reset the filter time
      # to ensure we didn't miss anything
      if @scans_without_change > MAX_POLLS_WITHOUT_CHANGE
        @last_seen = @log_sink.start_time
        @scans_without_change = 0
      else
        @last_seen = Time.now
      end

      # we found the last script, do any analysis here... (or in the log, or in the sink)
      if script_log = @log_sink.end_of_deployment_script
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