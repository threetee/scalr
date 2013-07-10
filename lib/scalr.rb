require 'rubygems'
require 'active_support/core_ext'

require File.dirname(__FILE__) + '/scalr/response'
require File.dirname(__FILE__) + '/scalr/request'
require File.dirname(__FILE__) + '/scalr/core_extensions/hash'
require File.dirname(__FILE__) + '/scalr/core_extensions/http'

module Scalr

  # set to a debugging output stream for HTTP request/response, nil for none
  mattr_accessor :debug
  @@debug = nil

  mattr_accessor :endpoint
  @@endpoint = "api.scalr.net"
  
  mattr_accessor :key_id
  @@key_id = nil
  
  mattr_accessor :access_key
  @@access_key = nil
  
  mattr_accessor :version
  @@version = "2.0.0"

  @@aliases = {}

  class << self

    def add_alias(type, name, alias_to_add)
      type = type.downcase
      name = name.downcase
      @@aliases[type] ||= {}
      @@aliases[type][name] ||= []
      if alias_to_add.instance_of?(Array)
        alias_to_add.each{|to_add| @@aliases[type][name] << to_add.downcase}
      else
        @@aliases[type][name] << alias_to_add.downcase
      end
    end

    def aliases(type)
      @@aliases[type.downcase] || {}
    end

    def has_aliases?(type)
      aliases(type).size > 0
    end

    def is_alias?(type, name, alias_to_check)
      type = type.downcase
      name = name.downcase
      @@aliases[type] && @@aliases[type][name] && @@aliases[type][name].include?(alias_to_check.downcase)
    end

    def method_missing(method_id, *arguments)
      if matches_action? method_id
        request = Scalr::Request.new(method_id, @@endpoint, @@key_id, @@access_key, @@version, arguments)
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
