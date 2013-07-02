require 'pathname'

module Scalr
  Scalr.version = '2.3.0'

  def self.read_access_info
    if ENV['SCALR_KEY_ID'] && ENV['SCALR_ACCESS_KEY']
      Scalr.key_id = ENV['SCALR_KEY_ID']
      Scalr.access_key = ENV['SCALR_ACCESS_KEY']
    elsif access_file = resolve_access_info_file
      values = Scalr.hash_from_file(access_file)
      Scalr.key_id = values[:key_id]
      Scalr.access_key = values[:access_key]
    else
      raise "No access information found in environment or file 'access_info'"
    end
  end

  def self.hash_from_file(filename)
    raise "File does not exist [Given: #{filename}]" unless File.exists?(filename)
    h = {}
    File.readlines(filename).each do |line|
      key, value = line.strip!.split(/\s*=\s*/, 2)
      h[key.downcase.to_sym] = value
    end
    h
  end

  def self.resolve_access_info_file
    found = nil
    [File.expand_path('../../../access_info', Pathname.new(__FILE__).realpath), # scalr gem
     File.expand_path('~/.ttm_scalr_access_info'),                              # home dir
     File.expand_path('./access_info')                                          # current dir
    ].each do |path|     
      found = path if File.exists?(path)
    end
    found
  end
end
