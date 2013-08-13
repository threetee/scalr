module Scalr
  class Ssher
    attr_reader :params

    def initialize(params)
      @params  = params
    end

    def execute(remote_command = '')
      response = dispatch(:farm_get_details, params)
      return if generic_error(response)

      server = Scalr::ResponseObject::FarmRole.
                 single_server(response.content, params['server'].value)

      unless server
        $stderr.puts("Failed to identify server with: #{params['server'].value}")
        exit_status 1
        return
      end

      farm_id = response.request_inputs['FarmID']
      key_path = File.expand_path("~/.ssh/FARM-#{farm_id}.#{server.platform_properties.availability_zone_brief}.private.pem")
      if File.exists?(key_path)
        cmd = ( params.has_key?('cmd')? params['cmd'].value : "ssh" )
        command = "#{cmd} -i #{key_path} root@#{server.external_ip} #{remote_command}"
        puts "Executing `#{command}`"
        exec command
      else
        $stderr.puts(<<-KEYFILE.gsub(/^ {10}/, ''))

          Expected key file (#{key_path}) does not exist.
          Here's how to fix it:
            - go to https://my.scalr.com/#/sshkeys/view
            - find the row with the 'Farm ID' column as #{farm_id}
            - click the 'Actions' dropdown in its far right column
            - choose 'Download private key'
            - store it to #{key_path}
            - execute: 'chmod 400 #{key_path}'
              (so ssh won't complain about permissive permissions)
        KEYFILE
        exit_status 1
      end
    end

    def dispatch(action_name, params)
      Scalr::Caller.new(action_name).dispatch(params)
    end
  end
end
