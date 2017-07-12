require_relative '../lib/scalr'
require_relative './common.rb'

class ListVariablesForFarms < ScalrScript
  def execute
    response = Scalr.farms_list
    farms = {}
    if response.successful_request?
      response.content.each do |farm_info|
        out "Farm: #{farm_info[:name]} (ID: #{farm_info[:id]})"
        farms[:name] = {}
        variable_response = Scalr.global_variables_list(farm_id: farm_info[:id])
        if variable_response.content.nil? || variable_response.content.empty?
          out '  NO VARIABLES FOUND'
        else
          variable_response.content.each do |pair|
            farms[:name][ pair[:name] ] = pair[:value]
            out sprintf('  %-25s: %s', pair[:name], pair[:value])
          end
        end
      end
    else
      out   "Error! [Code: #{response.code}] [Message: #{response.message}]"
    end
    farms
  end
end

if __FILE__ == $0
  Scalr.read_access_info
  Scalr.version = '2.3.0'
  #Scalr.debug = $stdout

  ListVariablesForFarms.new.execute
end