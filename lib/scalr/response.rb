require 'rexml/document'

module Scalr
  class Response
    
    attr_accessor :code, :content, :error, :message, :transaction_id, :value
      
    def initialize(response, data, request_metadata)
      @code = response.code
      @message = response.message
      if successful_request?
        @value = parse(data)
        if success?
          @content, @transaction_id = smart_parse(request_metadata, @value)
        else
          @error = @value[:error][:message]
        end
      end
    end
    
    def successful_request?
      @code == '200'
    end
    
    def success?
      successful_request? && @value[:error].nil?
    end
    
    def failed?
      !success?
    end
    
private
    
    def parse(data)
      Hash.from_xml(data).recursive_downcase_keys!
    end

    # see info in Scalr::Request about request_metadata
    def smart_parse(request_metadata, hash)
      return hash unless request_metadata[:outputs]
      keys = request_metadata[:outputs][:path].split(/[@\/]/)
      top_element = (request_metadata[:name].downcase + 'response').to_sym
      current_value = hash[top_element]
      transaction_id = current_value[:transactionid]
      keys.each do |key|
        next if current_value.nil? # don't keep descending if parent is nil
        current_value = current_value[key.to_sym]
      end
      [current_value, transaction_id]
    end
  end
end