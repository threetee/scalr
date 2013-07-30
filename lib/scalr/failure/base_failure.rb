module Scalr::Failure
  class BaseFailure

    DISPLAY_AROUND = 4

    attr_accessor :log_item

    def initialize(log_item)
      @log_item = log_item
    end

    def display_after
      DISPLAY_AROUND
    end

    def display_before
      DISPLAY_AROUND
    end

    def error_for_display(context = nil)
      lines = log_item.message.split(/[\r\n]/)
      display_chunks = []
      lines.each_with_index do |line, index|
        next unless line.match(pattern)
        display_chunks << (index-display_before..index+display_after).map {|line_index|
          line_index < 0 || line_index > lines.length ? nil : "#{line_index}: #{lines[line_index]}"
        }.compact.join("\n")
      end
      display_chunks.join("\n----\n")
    end

    def matches?
      ! log_item.message.match(pattern).nil?
    end

    def pattern
      /.+/
    end
  end
end
