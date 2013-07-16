module Scalr
  class Caller

    # to save typing we map parameters to shorter names
    #   Scalr API name   => Our short name
    PARAM_ALIASES = {
        application_id:     :application,
        farm_id:            :farm,
        records_limit:      :limit,
        remote_path:        :path,
        farm_role_id:       :role,
        script_id:          :script,
        server_id:          :server,
        start_from:         :start,
        deployment_task_id: :task,
    }

    def self.collect_options(params, api_names)
      new(nil).collect_options(params, api_names)
    end

    def initialize(action_name)
      @action_name  = action_name
      unless @action_name.nil? # hack!
        @request_info = Scalr::Request.action(action_name)
        raise "Unknown action [Given: #{action_name.to_s}]" unless @request_info
      end
      @partial_options = {}
    end

    # store options away until later, will be re-used
    # with every invoke()
    def partial_options(options)
      @partial_options = @partial_options.merge(options)
      self
    end

    def dispatch(params)
      options = collect_options(params, @request_info[:inputs].keys)
      invoke(options)
    end

    def invoke(options = {})
      valid_keys = @request_info[:inputs].keys
      valid_options = options.
          merge(@partial_options).
          delete_if {|key,_| !valid_keys.include?(key)}
      begin
        Scalr.send(@action_name, valid_options)
      rescue Scalr::Request::InvalidInputError => e
        $stderr.puts("ERROR: #{e.message}")
        nil
      end
    end

    # allow use of either our short name or Scalr API name
    # return: hash of API option name (e.g., :farm_id) to value that
    #         will be used for that option
    def collect_options(params, api_names)
      options = {}
      api_names.each do |api_name|
        cli_name = map_parameter_key(api_name)
        first_value = first_value_for(params, cli_name, api_name)
        value = transform_value(api_name, first_value, params)
        options[api_name] = value if value
      end
      options
    end

    def map_parameter_key(key)
      PARAM_ALIASES[key.to_sym] || key.to_sym
    end

    def first_value_for(params, *keys)
      keys.each do |key|
        option = option_by_name(params, key)
        if option
          value = option.values.length > 1 ? option.values : option.value
          return value if value
        end
      end
      nil
    end

# Note that we're using params.find vs params['name'] because
# the latter kills the program (weird!)
    def option_by_name(params, name)
      params.find {|option| option.name.to_s == name.to_s}
    end

# allow transformations/lookups of data from the user
    def transform_value(name, value, params)
      if name == :farm_id && ! value.nil?
        resolve_farm(value)
      elsif name == :farm_role_id && option_by_name(params, 'farm') && ! value.nil?
        roles = resolve_farm_role(value, params)
        if roles.empty?
          raise "Cannot resolve farm role [Farm: #{params['farm'].value}] [Role: #{value}]"
        else
          roles.first
        end
      elsif name == :server_id && ! value.nil?
        if match_info = value.match(/^(\w+)\.(\d+)$/) # heroku format
          role_name = match_info[1]
          server_index = match_info[2]
          roles = resolve_farm_role(role_name, params)
          if roles.empty?
            raise "Cannot resolve farm role [Farm: #{params['farm'].value}] [Role: #{role_name}]"
          end
          server_guid = resolve_server_index(server_index, params, roles.first)
          if server_guid.nil?
            raise "Cannot resolve server index to GUID [Farm: #{params['farm'].value}] [Role/server: #{value}]"
          end
          server_guid
        elsif value.to_s.length < 10 # < 4 => int, < 10 => string with ID start (short hash)
          server_guid = resolve_server_index(value, params)
          if server_guid.nil?
            raise "Cannot resolve server index to GUID [Farm: #{params['farm'].value}] [Role: #{params['role'].value}] [Server index: #{value}]"
          end
          server_guid
        else
          value
        end
      elsif name == :application_id && ! value.nil?
        resolve_application(value)
      else
        value
      end
    end

    def resolve_application(app_alias)
      return app_alias if app_alias.match(/^\d+$/) || Scalr.is_aliased_name?('application', app_alias)
      Scalr.match_alias('application', app_alias)
    end

    def resolve_farm(farm_alias)
      return farm_alias if farm_alias.match(/^\d+$/) || Scalr.is_aliased_name?('farm', farm_alias)
      Scalr.match_alias('farm', farm_alias)
    end

# returns an array of farm role IDs
    def resolve_farm_role(name, params, response = nil)
      role_names = []
      if Scalr.is_aliased_name?('role', name)
        role_names << name
      elsif name != 'all'
        role_names << Scalr.match_alias('role', name)
      end

      unless response
        response = self.class.new(:farm_get_details).dispatch(params)
        unless response.success?
          $stderr.puts('Failed to get farm details!')
          #generic_error(response)
          return []
        end
      end

      response.content.
          find_all {|role_info| name == 'all' || role_names.include?(role_info.name.downcase)}.
          map {|role_info| role_info.id}
    end

    # given a count of a server within a role, or a string with the start of a GUID,
    # resolve it to a fully-qualified  server ID (GUID)
    def resolve_server_index(index, params, role_id = nil)
      response = self.class.new(:farm_get_details).dispatch(params)
      return nil unless response.success?

      # if we have a role available to disambiguate, use it
      if role_id
        role = response.content.find {|role_info| role_id.to_s == role_info[:id]}
        unless role
          raise "No role with ID #{role_id} exists in farm #{params['farm'].value}"
        end
        servers = role.servers
      elsif option_by_name(params, 'role') && params['role'].given?
        role_ids = resolve_farm_role(params['role'].value, params, response)
        servers = response.content.find {|role_info| role_ids.include?(role_info[:id])}.servers
      else
        servers = response.content.flat_map {|role_info| role_info.servers}
      end

      if index.to_s.length > 4
        matching = servers.find_all {|server| server.id.match(/^#{index.to_s}/)}
      else
        matching = servers.find_all {|server| index.to_i == server.index}
      end


      # if too many, remove non-running ones
      if matching.length > 1
        matching = servers.find_all {|server| server.running?}
      end

      # if STILL too many you probably didn't assign a role...
      if matching.length > 1
        raise "Too many servers match index '#{index}' within the farm! Specify a role to disambiguate."
      end

      matching.empty? ? nil : matching.first.id
    end
  end
end