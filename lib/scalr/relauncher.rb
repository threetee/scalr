require 'scalr'
require 'scalr/caller'
require 'pry'

class ReplacementServer
  attr_accessor :status
  attr_reader :server_id, :target, :name

  def initialize(target, server_id, name)
    @target = target
    @server_id = server_id
    @status = :Pending
    @name = name
  end
end

class ReplacementStatus
  attr_accessor :running, :booting

  def initialize(role, running, booting)
    @role = role
    @running = running
    @booting = booting
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
    @roles.each do |role|
      launched_servers = []
      role.servers.each do |server|
        response = perform_launch({:farm_id => @farm_id, :farm_role_id => role.id})
        name = sprintf("%s-%s", role.name, server.index)
        launched_servers << ReplacementServer.new(server.id, response.content, name)
        break
      end
      @replacements.store(role.id, launched_servers)
      break
    end
    puts "Launched - #{@replacements}"
  end

  def update_role_status

  end

  def monitor
    pending = true

    while pending
      pending = false
      @replacements.each do |role, servers|
        pending_servers = servers.select { |s| s.status != :Running }
        if pending_servers.length > 0
          update_launch_status
          pending = true
          next
        end
      end
    end
  end

  private

  def update_launch_status
    farm_status = get_farm_status
    farm_status.each { |role|
      servers = role.servers
      replacement_servers = @replacements[role.id]
      if replacement_servers
        replacement_servers.each { |replacement|
          server = servers.select { |x| x.id == replacement.server_id }
          replacement.status = server[0].status.to_sym
          puts "#{replacement.target} - #{replacement.name} -> #{server[0].id} -> #{server[0].status}"
        }
      end
    }
  end

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