require 'rexml/document'

module Scalr
  class Response
    
    attr_accessor :code, :message, :value, :error
      
    def initialize(response, data)
      @code = response.code
      @message = response.message
      if successful_request?
        @value = parse(data)
        @error = @value[:error][:message] if !success?
      end
    end
    
    def successful_request?
      (@code == '200')
    end
    
    def success?
      (successful_request? && @value[:error].nil?)
    end
    
    def failed?
      !success?
    end
    
    private 
    
      def parse(data)
        Hash.from_xml(data).recursive_downcase_keys!
      end
    
  end
end