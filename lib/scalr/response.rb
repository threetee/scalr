require 'rexml/document'

module Scalr
  module Response
    
    def initialize(response, data)
      @code = response.code
      @message = response.message
      if success?
        @response = parse(data)
      end
    end
    
    def success?
      (@code == '200')
    end
    
    def failed?
      !success?
    end
    
    private 
    
      def parse(data)
        response = {}
        xml = REXML::Document.new(data)
        xml.elements.to_a.each do |node|
          parse_element(response, node)
        end
        response
      end

      def parse_element(response, node)
        node_name = node.name.underscore.to_sym
        case
        when node.has_elements?
          node.elements.each{|e| parse_element(response[node_name], e) }
        else
          response[node_name] = node.text
        end
      end
    
  end
end