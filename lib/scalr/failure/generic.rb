module Scalr::Failure
  class Generic < BaseFailure
    def description(context = nil)
      '(see log message)'
    end

    # display the entire message rather than pieces since we can't
    # pick out the relevant parts
    def error_for_display(context = nil)
      log_item.message
    end

    def matches?
      true
    end

    def name
      'Uncategorized failure'
    end
  end
end