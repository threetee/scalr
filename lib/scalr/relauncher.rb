require 'scalr'
require 'scalr/caller'

class Relauncher
  def initialize(farm_id, roles)
    @roles = roles
    @farm_id = farm_id
    @launched_servers = []
  end

  def launch
    @roles.each {|role|
      @launched_servers << perform_launch({:farm_id => @farm_id, :farm_role_id => role.id})
      break
    }
  end

  private

  def perform_launch(options)
    invoke(:server_launch, options)
  end

  def invoke(action_name, options = {})
    Scalr::Caller.new(action_name).invoke(options)
  end

end