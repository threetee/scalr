module Scalr
  # this is kind of gross -- the response has a status, but it's really just
  # indicating "yeah I executed your script" -- instead, you have to look at the scripting
  # log for each of the servers you executed against and check the exit code...
  # AND
  # we have to do so in a loop, as 'async' doesn't mean what you think it means...
  class Poller
    SLEEP_TIME = 5
    MAX_POLLS  = 5

    def initialize(farm_id, servers)
      @farm_id = farm_id
      @servers = servers || []
    end

    def server_count
      @servers.length
    end

    def script_logs(script_name, script_time)
      script_log_options = {farm_id: @farm_id}

      count = 1

      matching_logs = []

      loop do
        break if count > MAX_POLLS
        break if server_count != 0 && matching_logs.length == server_count
        break if server_count == 0 && matching_logs.length > 0

        print '.'
        sleep(SLEEP_TIME)

        log_response = invoke(:script_logs_list, script_log_options)
        if generic_error(log_response)
          raise 'Failed to fetch logs to display the scripting error. Check scalr website: https://my.scalr.com/#/logs/scripting'
        end
        matching_logs = log_response.content.find_all do |log_item|
          log_item.after?(script_time) && log_item.script_matches(script_name)
        end
        count += 1
      end

      print "\n"
      matching_logs
    end

  end
end