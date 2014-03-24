require 'scalr'
require 'scalr/caller'
require 'scalr/check_online_status'

class ReplacementServer
  attr_accessor :status, :ip, :ok_to_terminate
  attr_reader :server_id, :target, :name

  def initialize(target, server_id, target_name)
    @target = target
    @server_id = server_id
    @status = :Pending
    @target_name = target_name
    @ip = ''
    @ok_to_terminate = false
  end
end

class ReplacementStatus
  attr_accessor :running, :booting, :failed

  def initialize(running, booting, failed)
    @running = running
    @booting = booting
    @failed = failed
  end
end

class Relauncher
  def initialize(farm_id, roles)
    @roles = roles
    @farm_id = farm_id
    @replacements = {}
    @replacement_status = {}
  end

  def relaunch
    launch
    monitor
    terminate
  end

  private

  def launch
    @roles.each do |role|
      launched_servers = []
      role.servers.each do |server|
        if server.status == 'Running'
          response = perform_launch({:farm_id => @farm_id, :farm_role_id => role.id, :increase_max_instances => true})
          target_name = sprintf("%s-%s", role.name, server.index)
          launched_servers << ReplacementServer.new(server.id, response.content, target_name)
        end
      end
      @replacements.store(role.id, launched_servers)
    end
  end

  def monitor
    monitor_boot_status
    status_checker = CheckOnlineStatus.new(@replacements, '/users/sign_in')
    status_checker.check
  end

  def terminate
    @replacements.each { |role, servers|
      servers.each { |server|
        puts "Terminating: #{server.target_name}"
        perform_terminate({:farm_id => @farm_id, :server_id => server.server_id, :decrease_min_instances_setting => true})
      }
    }
  end

  def update_launch_status
    farm_status = get_farm_status
    farm_status.each { |role|
      servers = role.servers
      replacement_servers = @replacements[role.id]
      unless replacement_servers.empty?
        replacement_servers.each do |replacement|
          server = servers.select { |x| x.id == replacement.server_id }
          replacement.status = server[0].status.to_sym
          replacement.ip = server[0].external_ip
        end
      end
    }
  end

  def monitor_boot_status
    pending = true

    while pending
      pending = false
      @replacements.each do |role , servers|
        update_replacement_status

        @replacement_status.each { |role_id, status|
          puts "Role #{role_id} - Running #{status.running} - Booting #{status.booting} - Failed #{status.failed}"
        }

        pending_servers = servers.select { |s| s.status != :Running && s.status != :Failed }
        if pending_servers.length > 0
          update_launch_status
          pending = true
          sleep 30
          next
        end
      end
    end
  end

  def update_replacement_status
    @replacement_status = {}
    @replacements.each do |role, servers|
      pending_servers = servers.select { |s| s.status == :Pending || s.status == :Initializing }
      running_servers = servers.select { |s| s.status == :Running }
      failed_servers = servers.select { |s| s.status == :Failed }
      stat = ReplacementStatus.new(running_servers.length, pending_servers.length, failed_servers.length)
      @replacement_status.store(role, stat)
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
    roles = []
    role_response = invoke(:farm_get_details, farm_id: @farm_id)
    roles = role_response.content.reject {|role| role.name.match(/(PGSQL|lb\-nginx)/)}
    roles.compact!
    raise 'Cannot determine role script executes in - weird!' if roles.empty?
    roles
  end

end