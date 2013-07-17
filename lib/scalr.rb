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

  @@aliases = nil

  mattr_accessor :alias_reader
  @@alias_reader = nil

  class << self

    def add_alias(type, name, alias_to_add)
      type = type.downcase
      name = name.downcase
      @@aliases ||= {}
      @@aliases[type] ||= {}
      @@aliases[type][name] ||= []
      if alias_to_add.instance_of?(Array)
        alias_to_add.each{|to_add| @@aliases[type][name] << to_add.downcase}
      else
        @@aliases[type][name] << alias_to_add.downcase
      end
    end

    def aliases(type, name = nil)
      read_aliases if @@aliases.nil?
      a = @@aliases[type.downcase] || {}
      name.nil? ? a : a[name.downcase] || []
    end

    def first_alias(type, name)
      a = aliases(type, name)
      a.empty? ? nil : a.first
    end

    def has_aliases?(*types)
      return false if @@aliases.nil? || @@aliases.empty?
      types.all? {|type| aliases(type).size > 0}
    end

    def is_alias?(type, name, alias_to_check)
      aliases(type, name).include?(alias_to_check.downcase)
    end

    def is_aliased_name?(type, name)
      aliases(type).keys.include?(name.downcase)
    end

    def match_alias(type, to_match)
      aliases(type).each do |name, aliases|
        return name if aliases.include?(to_match)
      end
      nil
    end

    def read_aliases
      if @@alias_reader.nil?
        $stderr.puts('Cannot read aliases: no Scalr.alias_reader assigned!')
        @@aliases = {}
      else
        all_aliases = @@alias_reader.read_aliases
        if all_aliases
          all_aliases.each do |alias_type, alias_map|
            alias_map.each{|name, aliases| Scalr.add_alias(alias_type, name, aliases)}
          end
        end
      end
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
