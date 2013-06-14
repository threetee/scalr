require_relative '../lib/scalr'
require_relative './common.rb'

Scalr.read_access_info
#Scalr.debug = $stdout

Scalr.version = '2.3.0'

response = Scalr.farms_list
if response.successful_request?
  response.content.each do |farm_info|
    puts "Farm: #{farm_info[:name]} (ID: #{farm_info[:id]})"
    variable_response = Scalr.global_variables_list(farm_id: farm_info[:id])
    if variable_response.content.nil? || variable_response.content.empty?
      puts '  NO VARIABLES FOUND'
    else
      variable_response.content.each do |pair|
        puts sprintf('  %-25s: %s', pair[:name], pair[:value])
      end
    end
  end
else
  puts "Error! [Code: #{response.code}] [Message: #{response.message}]"
end
