require 'HTTParty'

class CheckOnlineStatus

  def initialize(roles, replacement_status, resource, update_callback)
    @roles = roles
    @resource = resource
    @replacement_status = replacement_status
    @update_callback = update_callback
  end

  def check
    pending = true
    while pending
      pending = false
      @update_callback.call
      @roles.each do |role, servers|
        servers_to_check = servers.select { |s| ! s.ok_to_terminate }
        if servers_to_check.length > 0
          @replacement_status[role].checking = 'Yes '
          check_servers(@replacement_status[role], servers_to_check)
          pending = true
        else
          @replacement_status[role].checking = 'Done'
        end
      end
      sleep 10
    end
  end

  private

  def check_servers(role_status, servers_to_check)
    servers_to_check.each do |server|
      if server.target_name =~ /RailsAppServer/
        http_check(role_status, server)
      else
        server.ok_to_terminate = true
        role_status.terminate_ready += 1
      end
    end
  end

  def http_check(role_status, server)
    begin
      response = HTTParty.get("http://#{server.ip}#{@resource}")
      if response =~ /Welcome to Think Through Math/
        server.ok_to_terminate = true
        role_status.terminate_ready += 1
      end
    rescue
      server.ok_to_terminate = false
    end
  end

end