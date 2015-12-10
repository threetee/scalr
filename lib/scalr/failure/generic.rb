module Scalr::Failure
  class Generic < BaseFailure
    def description(context = nil)
      '(see log message)'
    end

    # display the entire message rather than pieces since we can't
    # pick out the relevant parts
    def error_for_display(context = nil)
      if log_item.message
        log_item.message
      elsif log_item.respond_to?(:exit_code)
        "No log message [Exit code: #{log_item.exit_code}]"
      else
        "No log message or exit code - #{log_item.inspect}"
      end
    end

    def matches?
      true
    end

    def name
      'Uncategorized failure'
    end
  end
end