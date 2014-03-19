require 'scalr'
require 'scalr/caller'
require 'pry'

class Relauncher
  def initialize(farm_id, roles)
    @roles = roles
    @farm_id = farm_id
    @replacements = {}
    @roles = roles
  end

  def launch
    @roles.each { |role|
      launch_ids = []
      role.servers.each { |server|
        response = perform_launch({:farm_id => @farm_id, :farm_role_id => role.id})
        launch_ids << {:target_id => server.id, :replacement_id => response.content}
        break
      }
      @replacements.store(role.id, launch_ids)
      break
    }
    puts "Launched - #{@replacements}"
  end

  def monitor
    farm_status = get_farm_status

    farm_status.each { |role|
      servers = role.servers
      replacement_ids = @replacements[role.id]
      replacement_ids.each { |replacement|
        server = servers.select { |x| x.id == replacement[:replacement_id] }
        puts "#{replacement[:target_id]} -> #{server[0].id} -> #{server[0].status}"
      }
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