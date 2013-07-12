module Scalr
  class DeploymentMonitor
    def initialize(options)
      @application_id = options[:application_id]
      @farm_id = options[:farm_id]
      @role_id = options[:role_id]
      @tasks = options[:tasks]
    end

    def run
      puts "Nothing to see here yet..."
    end
  end
end