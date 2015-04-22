require 'scalr'
require 'scalr/caller'
require 'scalr/check_online_status'

class ServerInstance
  attr_accessor :status
  attr_reader :id, :role

  def initialize(id, role, status = :Original)
    @id = id
    @role = role
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
    @recycle_increment = {RailsAppServer: 5, Sidekiq: 2, Reports: 2, Bunchball: 1, DevDebug: 1, SystemWatcher: 1}
  end

  def recycle
    setup
    while @servers.length > 0 do
      @roles.each do |role|
        launch_replacements(role)
      end

      monitor_startup

      @roles.each do |role|
        #terminate_originals(role)
      end
    end
  end

  private

  def setup
    @roles_to_recycle.each do |role|
      @roles << Role.new(role.name, role.id)
      role.servers.each do |server|
        @servers << ServerInstance.new(server.id, role.name) if server.status == 'Running'
      end
    end
  end

  def launch_replacements(role)
    servers_to_launch = @servers.select { |server|
      server.role == role.name && server.status == :Original
    }.first(@recycle_increment[role.name.to_sym])

    servers_to_launch.each do |server|
      response = perform_launch({farm_id: @farm_id, farm_role_id: role.id, increase_max_instances: true})
      @replacement_servers << ServerInstance.new(response.content, role.name, :New)
      @servers.map! do |s|
        (s.id == server.id) ? ServerInstance.new(s.id, s.role, :Launched) : s
      end
    end
  end

  def monitor_startup
    pending = true
    while pending
      update_launch_status
      pending_servers = @replacement_servers.select { |s| s.status == :New}
      puts pending_servers.inspect
      if pending_servers.length == 0
        pending = false
      end
      sleep 10
    end
  end

  def update_launch_status
    farm_status = get_farm_status
    farm_status.each do |role|
      farm_servers = role.servers
      @replacement_servers.map! do |server|
        fs = farm_servers.select { |s| s.id == server.id }.first
        puts fs.inspect
        if fs.status == 'Running'
          ServerInstance.new(server.id, server.role, :Up)
        else
          server
        end
      end
    end
  end

  def terminate_originals(role)
    servers_to_terminate = @servers.select { |server| server.role == role.name && server.status == :Old}
    count = @recycle_increment[role.name.to_sym] > servers_to_terminate.length ? servers_to_terminate.length : @recycle_increment[role.name.to_sym]
    (0..(count - 1)).each do |index|
      puts servers_to_terminate[index].inspect
      #perform_terminate({:farm_id => @farm_id, :server_id => server.target, :decrease_min_instances_setting => false})
      @servers.delete_if do |server|
        server.id == servers_to_terminate[index].id
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