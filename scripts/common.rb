module Scalr
  def self.read_access_info
    if ENV['SCALR_KEY_ID'] && ENV['SCALR_ACCESS_KEY']
      Scalr.key_id = ENV['SCALR_KEY_ID']
      Scalr.access_key = ENV['SCALR_ACCESS_KEY']
    elsif File.exists?('access_info')
      values = Scalr.hash_from_file('access_info')
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
end
