require 'delegate'

module Scalr
  class ServerFailure < ::SimpleDelegator

    attr_reader :failures, :server

    TYPES = []

    def self.add_failure_type(failure_class)
      TYPES << failure_class
    end

    def initialize(server, log_item)
      super(log_item)
      @server = server
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

      # generate the actual error suitable for display
    # ++context++ a hash of data that may be useful to fetch additional information
    # from scalr -- e.g., :farm_id so we can fetch existing configuration values
    def for_display(context = {})
      my_context = context.merge(server: @server)
      @failures.map do |failure|
        log_snippets = failure.error_for_display(my_context)
        [failure.name, failure.description(my_context), log_snippets].join("\n")
      end
    end

    # 'sort' isa hack so that base_failure will be require'd first
    Dir[File.join(File.dirname(__FILE__), 'failure', '*.rb')].sort.each {|file| require file}
  end
end
