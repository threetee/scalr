# Checks the API setup for internal consistency and outputs requirements for each call.

$:.unshift File.expand_path("../../lib", __FILE__)
require 'scalr'

def actions
  Scalr::Request::ACTIONS
end

def all(args)
  actions.keys.sort.each do |ruby_name|
    show(ruby_name, actions[ruby_name])
  end  
end

def check(args)
  failures = 0
  actions.keys.sort.each do |ruby_name|
    config = actions[ruby_name]

    # find any issues, currently limited to parameters not being mapped
    issues = find_issues(config)
    next if issues.empty?
    failures += 1
    puts "#{show_name_and_version(ruby_name, config)}: FAILURE"   
    puts issues.join("\n") unless issues.empty?
    puts show_inputs(config).join("\n")
    puts ""
  end
  puts "EVERYTHING OK!!!!!"  if failures == 0
end

def help(args)
  puts <<-HELP
  #{$0} - Check/display Scalr API configuration

  Usage: #{$0} [action - defaults to 'check'] [arg...]
  
  Actions:
    all:   list all API calls and arguments
    check: display any API calls that are misconfigured
    help:  show this message
    match: list API calls and arguments where the call contains a string
  HELP
end

def match(args)
  return all(args) if args.empty?
  substring = args[0]
  actions.keys.sort.each do |ruby_name|
    show(ruby_name, actions[ruby_name]) if ruby_name.to_s.include?(substring)    
  end
end

def show(ruby_name, config)
  puts show_name_and_version(ruby_name, config)
  puts show_inputs(config).join("\n"), "\n"
end


def find_issues(api_config)
  issues = []
  api_config[:inputs].keys.each do |ruby_key|
    issues << "  -- Parameter missing XML mapping! #{ruby_key.to_s}" unless input_key_exists?(ruby_key)
  end
  issues
end

def input_key(key)
  Scalr::Request::INPUTS[key]
end

def input_key_exists?(key)
  ! input_key(key).nil?
end

def main(args)
  action = args.empty? ? 'check' : args.shift
  self.send(action.to_sym, args)
end

def show_inputs(config)  
  config[:inputs].keys.sort.map do |ruby_key|
    default_display = config[:defaults] && config[:defaults][ruby_key] ? " => default: #{config[:defaults][ruby_key]}" : ''
    "  => #{ruby_key} (#{input_key(ruby_key)}) [Required? #{config[:inputs][ruby_key].to_s}#{default_display}]"
  end
end

def show_name_and_version(key, config)
  "#{key.to_s} (#{config[:name]}) @ #{config[:version]}"
end

main(ARGV)
