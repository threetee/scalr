require 'delegate'

module Scalr
  class ServerFailure < ::SimpleDelegator

    attr_reader :failures, :server_deployment

    TYPES = []

    def self.add_failure_type(failure_class)
      TYPES << failure_class
    end

    def self.matches_any_failure?(message)
      TYPES.any? do |failure_class|
        p = failure_class.pattern
        p.nil? ? false : message.match(p)
      end
    end

    def initialize(server_deployment, log_item)
      super(log_item)
      @server_deployment = server_deployment
      @failures = categorize(log_item)
    end

    def categorize(log_item)
      matches = failure_types.map {|pattern_clazz|
        pattern = pattern_clazz.new(log_item)
        pattern.matches? ? pattern : nil
      }.compact
      matches.empty? ? [Scalr::Failure::Generic.new(log_item)] : matches
    end

    def failure_types
      TYPES
    end

    # generate the actual error suitable for display as an array of strings, one for each failure
    # ++context++ a hash of data that may be useful to fetch additional information
    # from scalr -- e.g., :farm_id so we can fetch existing configuration values
    def for_display(context = {})
      my_context = context.merge(
          server:            @server_deployment.server,
          server_deployment: @server_deployment,
          task:              @server_deployment.task)
      @failures.map do |failure|
        log_snippets = failure.error_for_display(my_context)
        [failure.name, failure.description(my_context), '', 'LOG:', log_snippets].join("\n")
      end
    end

    # 'sort' isa hack so that base_failure will be require'd first
    Dir[File.join(File.dirname(__FILE__), 'failure', '*.rb')].sort.each {|file| require file}
  end
end
