require 'scalr/server_failure'

module Scalr
  class LogSinks
    def initialize(sinks)
      @sinks = sinks
    end

    # distribute the log to the sink with the given ID
    def <<(id, log)
      sink = sink_by_id(id)
      sink << log if sink
    end

  private

    def sink_by_id(id)
      @sinks.find {|sink| id == sink.id}
    end
  end

  class LogSink
    attr_accessor :failures, :id, :start_time

    def initialize(id)
      @id = id
      @failures = []
      @logs = []
      @start_time = Time.now
    end

    def <<(log_to_add)
      existing = @logs.any? {|log| log_to_add.identifier == log.identifier}
      unless existing
        @logs << log_to_add
        @failures << log_to_add if has_failures?(log_to_add)
      end
      existing ? 0 : 1
    end

    def +(logs)
      logs.each {|log| self << log}
    end

    # retrieve the script that marks the end of a deployment
    def end_of_deployment_script
      scripting_logs.find {|log_item| log_item.script_name.match(/TTM_Launcher/)}
    end

    def scripting_logs
      logs_by_class(Scalr::ResponseObject::ScriptLogItem)
    end

    def system_logs
      logs_by_class(Scalr::ResponseObject::LogItem)
    end

    def task_logs
      logs_by_class(Scalr::ResponseObject::DeploymentTaskLogItem)
    end

  private

    # quick check to see if this log triggers any failures
    def has_failures?(log)
      if log.instance_of?(Scalr::ResponseObject::ScriptLogItem)
        log.failure?
      else
        Scalr::ServerFailure.matches_any_failure?(log.message)
      end
    end

    def logs_by_class(clazz)
      @logs.find_all {|log| log.instance_of? clazz}
    end
  end
end