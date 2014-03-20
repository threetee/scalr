require 'scalr'
require 'scalr/caller'
require 'pry'

class ReplacementServer
  attr_accessor :status
  attr_reader :server_id, :target

  def initialize(target, server_id)
    @target = target
    @server_id = server_id
    @status = :pending
  end
end

class Relauncher
  def initialize(farm_id, roles)
    @roles = roles
    @farm_id = farm_id
    @replacements = {}
    @roles = roles
  end

  def launch
    @roles.each { |role|
      launched_servers = []
      role.servers.each { |server|
        response = perform_launch({:farm_id => @farm_id, :farm_role_id => role.id})
        launched_servers << ReplacementServer.new(server.id, response.content)
        break
      }
      @replacements.store(role.id, launched_servers)
      break
    }
    puts "Launched - #{@replacements}"
  end

  def monitor
    farm_status = get_farm_status

    farm_status.each { |role|
      servers = role.servers
      replacement_servers = @replacements[role.id]
      if replacement_servers
        replacement_servers.each { |replacement|
          server = servers.select { |x| x.id == replacement.server_id }
          puts "#{replacement.target} -> #{server[0].id} -> #{server[0].status}"
        }
      end
    }
  end

  private

  def perform_launch(options)
    invoke(:server_launch, options)
  end

  def invoke(action_name, options = {})
    Scalr::Caller.new(action_name).invoke(options)
  end

  def get_farm_status
    roles = []
    role_response = invoke(:farm_get_details, farm_id: @farm_id)
    roles = role_response.content.reject {|role| role.name.match(/(PGSQL|lb\-nginx)/)}
    roles.compact!
    raise 'Cannot determine role script executes in - weird!' if roles.empty?
    roles
  end

end