require 'scalr'
require 'scalr/caller'

class ServerInstance
  attr_accessor :status
  attr_reader :id, :role, :index

  def initialize(id, role, index, status = :Original)
    @id = id
    @role = role
    @index = index
    @status = status
  end
end

class Role
  attr_accessor :name, :id

  def initialize(name, id)
    @name = name
    @id = id
    @finished = false
  end
end

class Recycler
  def initialize(farm_id, roles_to_recycle)
    @roles_to_recycle = roles_to_recycle
    @farm_id = farm_id
    @roles = []
    @servers = []
    @replacement_servers = []
    @recycle_increment = {RailsAppServer: 5, Sidekiq: 2, Reports: 1, Bunchball: 1, DevDebug: 1, SystemWatcher: 1}
  end

  def recycle
    setup
    while @servers.length > 0 do
      @roles.each do |role|
        launch_replacements(role)
      end
      monitor_startup
      @roles.each do |role|
        terminate_originals(role)
      end
    end
  end

  private

  def setup
    @roles_to_recycle.each do |role|
      @roles << Role.new(role.name, role.id)
      role.servers.each do |server|
        @servers << ServerInstance.new(server.id, role.name, server.index) if server.status == 'Running'
      end
    end
  end

  def launch_replacements(role)
    servers_to_launch = @servers.select { |server|
      server.role == role.name && server.status == :Original
    }.first(@recycle_increment[role.name.to_sym])

    servers_to_launch.each do |server|
      response = perform_launch({farm_id: @farm_id, farm_role_id: role.id, increase_max_instances: true})
      puts "Launching #{response.content} as a replacement for: #{server.role}-#{server.index}"
      @replacement_servers << ServerInstance.new(response.content, role.name, -1, :New)
      @servers.map! do |s|
        (s.id == server.id) ? ServerInstance.new(s.id, s.role, s.index, :Launched) : s
      end
    end
  end

  def monitor_startup
    pending = true
    while pending
      update_launch_status
      pending_servers = @replacement_servers.select { |s| s.status == :New}
      puts "Waiting for #{pending_servers.length} server(s) to transition to Running."
      pending = false if pending_servers.length == 0
      sleep 10
    end
  end

  def update_launch_status
    farm_status = get_farm_status
    farm_status.each do |role|
      role.servers.each do |server|
        @replacement_servers.map! do |rs|
          if rs.id == server.id && server.status == 'Running'
            ServerInstance.new(rs.id, rs.role, rs.index, :Up)
          else
            rs
          end
        end
      end
    end
  end

  def terminate_originals(role)
    servers_to_terminate = @servers.select { |server| server.role == role.name && server.status == :Launched}
    servers_to_terminate.each do |server|
      puts "Terminating #{server.role}-#{server.index}"
      perform_terminate({farm_id: @farm_id, server_id: server.id, decrease_min_instances_setting: true})
      @servers.delete_if do |s|
        s.id == server.id
      end
    end
  end

  def perform_terminate(options)
    invoke(:server_terminate, options)
  end

  def perform_launch(options)
    invoke(:server_launch, options)
  end

  def invoke(action_name, options = {})
    Scalr::Caller.new(action_name).invoke(options)
  end

  def get_farm_status
    farm_details = invoke(:farm_get_details, farm_id: @farm_id)
    roles = farm_details.content.reject {|role| role.name.match(/(PGSQL|lb\-nginx)/)}
    roles.compact!
    raise 'Cannot get Farm Status' if roles.empty?
    roles
  end

end