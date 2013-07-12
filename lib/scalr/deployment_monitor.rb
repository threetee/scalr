module Scalr
  class DeploymentMonitor
    def initialize(options)
      @application_id = options[:application_id]
      @farm_id = options[:farm_id]
      @role_id = options[:role_id]
      @tasks = options[:tasks]
    end

    def run
      puts Scalr::ResponseObject::DeploymentTaskItem.show_items(@tasks).join("\n")
      puts "Not ACTUALLY monitoring yet..."
    end
  end
end