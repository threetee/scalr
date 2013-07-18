module Scalr
  # this is kind of gross -- the response has a status, but it's really just
  # indicating "yeah I executed your script" -- instead, you have to look at the scripting
  # log for each of the servers you executed against and check the exit code...
  # AND
  # we have to do so in a loop, as 'async' doesn't mean what you think it means...
  class Poller
    SLEEP_TIME = 5
    MAX_POLLS  = 5

    def initialize(farm_id, servers, iteration_callback = ->(count) {print (count < 0 ? "\n" : '.')})
      @farm_id = farm_id
      @servers = servers || []
      @iteration_callback = iteration_callback
    end

    def server_count
      @servers.length
    end

    def script_logs(script_name, script_time, max_polls = MAX_POLLS)
      script_log_options = {farm_id: @farm_id}

      count = 1

      matching_logs = []

      loop do
        log_response = invoke(:script_logs_list, script_log_options)
        if generic_error(log_response)
          raise 'Failed to fetch logs to display the scripting error. Check scalr website: https://my.scalr.com/#/logs/scripting'
        end
        matching_logs = log_response.content.find_all do |log_item|
          log_item.after?(script_time) && log_item.script_matches(script_name)
        end
        count += 1

        break if count > max_polls
        break if server_count != 0 && matching_logs.length == server_count
        break if server_count == 0 && matching_logs.length > 0

        @iteration_callback.call(count-1)
        sleep(SLEEP_TIME)
      end
      @iteration_callback.call(-1)
      matching_logs
    end

  end

  # keep track of what we've seen in-between invocations; may be adapted to ask for logs
  # only from the unseen servers...
  class StatefulScriptPoller
    def initialize(farm_id, servers, script_name)
      @poller = Scalr::Poller.new(farm_id, servers, ->(_) {print '.'})
      @script_name = script_name
      @script_time = Time.now
      @fetched = Hash[servers.map{|server| [server.id, false]}]
    end

    def check(sinks)
      next_logs = @poller.script_logs(@script_name, @script_time, 1)
      next_logs.each do |log_item|
        @fetched[log_item.server_id] = true
        sinks << log_item
      end
      @script_time = Time.now
      completed?
    end

    def completed?
      @fetched.values.all?
    end

    def incomplete_servers
      @fetched.find_all {|_, fetched| fetched}.map {|pair| pair.first}
    end
  end
end