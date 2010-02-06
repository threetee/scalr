require 'active_support'

require File.dirname(__FILE__) + '/scalr/response'
require File.dirname(__FILE__) + '/scalr/request'

module Scalr
  
  mattr_accessor :endpoint
  @@endpoint = "api.scalr.net"
  
  mattr_accessor :api_key
  @@api_key = nil
  
  mattr_accessor :version
  @@version = "2009-05-07"
  
  class << self
    
    def method_missing(method_id, *arguments)
      if matches_action? method_id
        request = ScalrRequest.new(method_id, @@endpoint, @@api_key, @@version, arguments)
        return request.process!
      else
        super
      end
    end
    
    private
    
      def matches_action?(method_id)
        Scalr::Request::ACTIONS.keys.include? method_id.to_sym
      end
    
  end
  
end