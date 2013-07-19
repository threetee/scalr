module Scalr::Failure
  class Generic
    def description
      '(see log message)'
    end

    def matches?(log_item)
      true
    end

    def name
      'Uncategorized failure'
    end
  end
end