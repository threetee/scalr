module Scalr
  module ResponseObject
    class StructWithOptions < Struct
      def self.components
        {}
      end

      # since most of the field names we're using are just the original property names
      # with underscores in reasonable locations we can automate the conversion
      def self.fields
        Hash[ self.new.members.map{|field| [field.to_s.gsub(/_/, '').to_sym, field]} ]
      end

      def self.build(data)
        return nil unless data

        params = {}
        self.components.each do |k, info|
          component_data = data.nil? || data[k].nil? ? {} : data[k]
          params[info[:name]] = info[:clazz].build(component_data)
        end

        self.fields.each do |k,v|
          next if params[v] # don't overwrite components
          params[v] = data.nil? ? nil : data[k]
        end

        new(params)
      end

      def self.translate_array(possible_array, translation_object)
        return [] if possible_array.nil? || possible_array[:item].nil?
        items = possible_array[:item].instance_of?(Array) ? possible_array[:item] : [possible_array[:item]]
        items.map {|item_data| translation_object.build(item_data)}
      end

      def self.build_pattern(items, keys, template)
        lengths = scan_lengths(items, keys)
        lengths.each do |key, length|
          template = template.gsub(/\{#{key}\}/, "#{length}s")
        end
        template
      end

      def self.item_length(item)
        item.instance_of?(Fixnum) || item.instance_of?(Float) ? item.to_s.length : item.length
      end

      def self.scan_lengths(items, keys)
        pairs = keys.map do |key|
          max_length = items.map {|item|
            value = item.send(key.to_sym)
            value.nil? ? 0 : item_length(value)
          }.max
          [key, max_length]
        end
        Hash[pairs]
      end

      def initialize(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        super(*args)
        opts.each_pair{|k, v| self.send "#{k}=", v}
      end

      def parse_datestamp(date_string)
        Time.parse(date_string)
      end

      def parse_timestamp(epoch_seconds)
        Time.at(epoch_seconds.to_i)
      end

      def format_timestamp(timestamp)
        timestamp.strftime('%d %b %H:%M:%S')
      end
    end

    class Application < StructWithOptions.new(:id, :name, :source_id)
      def self.show_items(applications, sources)
        pat = build_pattern(applications, [:name, :id, :source_id],
                            '%-{name} [Application ID: %{id}] [Source: %s] (aliases: %s)')
        applications.map do |item|
          source_url = sources[item.source_id]
          aliases = Scalr.aliases('application', item.id)
          sprintf(pat, item.name, item.id, source_url, (aliases.empty? ? 'N/A' : aliases.join(', ')))
        end
      end
    end

    class ConfigVariable < StructWithOptions.new(:name)
    end

    class DeploymentTaskItem < StructWithOptions.new(:farm_role_id, :id, :remote_path, :server_id, :status)
      def self.fields
        super.merge(deploymenttaskid: :id)
      end

      def self.show_items(tasks)
        pat = build_pattern(tasks, [:id, :server_id, :status], '%-{id} - %-{status} [Server: %s]')
        tasks.map {|task| sprintf(pat, task.id, task.status, task.server_id)}
      end

      def deployed?
        status == 'deployed'
      end

      def deploying?
        status == 'deploying'
      end

      def failed?
        status == 'failed'
      end

      def failure_url
        "https://my.scalr.com/#/dm/tasks/#{id}/failureDetails"
      end

      def log_url
        "https://my.scalr.com/#/dm/tasks/#{id}/logs"
      end

      def pending?
        status == 'pending'
      end

      def server_short
        server_id.gsub(/^(\w+)\-.+$/, '\1')
      end

      def to_s
        "#{id}: #{status} [Server: #{server_id}]"
      end

      # {:serverid=>"57f02c81-6020-408a-8125-eecffa838673", :deploymenttaskid=>"f81461e34ce3",
      #  :farmroleid=>"53494", :remotepath=>"/var/www", :status=>"pending"}
    end

    class DeploymentTaskLogItem < StructWithOptions.new(:id, :message, :timestamp, :type)
      def self.build(data)
        obj = super(data)
        if obj
          obj.timestamp = obj.parse_timestamp(obj.timestamp)
        end
        obj
      end

      def identifier
        "DEPLOY #{id}-#{timestamp_formatted}"
      end

      def message_trimmed
        message.gsub(/[\r\n]/, ' ').rstrip
      end

      def timestamp_formatted
        format_timestamp(timestamp)
      end
    end

    class FarmRole < StructWithOptions.new(:id, :name, :role_id, :platform, :category, :cloud_location,
                                           :is_scaling, :scaling_properties, :platform_properties, :servers)
      def self.components
        {
            scalingproperties: {name: :scaling_properties, clazz: Scalr::ResponseObject::Scaling},
            platformproperties: {name: :platform_properties, clazz: Scalr::ResponseObject::Platform}
        }
      end

      def self.fields
        super.merge(isscalingenabled: :is_scaling)
      end

      def self.build(data)
        obj = super(data)
        if obj
          obj.servers = self.translate_array(data[:serverset], Scalr::ResponseObject::Server)
        end
        obj
      end

      def self.find_servers(roles, server_spec)
        roles.map {|role| role.find_server(server_spec)}.compact
      end

      def self.single_server(roles, server_spec)
        servers = Scalr::ResponseObject::FarmRole.find_servers(roles, server_spec)
        return servers.first if servers.length == 1

        if servers.empty?
          $stderr.puts('No such server found!')
        else
          $stderr.puts('Multiple servers identified:')
          $stderr.puts(Scalr::ResponseObject::Server.show_items(servers).join("\n"))
        end
        nil
      end

      # 'server_spec' could be an index (1), or role.index (rails.1), or server GUID
      # will return a ::Server object if matching or nil (if not found)
      def find_server(server_spec)
        if server_spec.to_s.match(/^([\d\w]+\-){4}[\d\w]+$/)
          return filter_by_running(->(server) {server_spec == server.id})
        end
        index = -1
        if match_info = server_spec.match(/^(\w+)\.(\d+)$/)
          role_name = match_info[1]
          index = match_info[2].to_i if Scalr.is_alias?('role', name, role_name)
        elsif server_spec.match(/^\d+$/)
          index = server_spec.to_i
        end

        return nil if index == -1
        filter_by_running(->(server) {index == server.index})
      end

      def filter_by_running(filter)
        matching = servers.find_all &filter
        if matching.length > 1
          matching = matching.find {|server| server.running?}
        end
        matching.empty? ? nil : matching.first
      end

      def for_display
        my_alias = Scalr.first_alias('role', name)
        servers_display = servers.empty? ? ['None'] : Scalr::ResponseObject::Server.show_items(servers, my_alias)
        aliases = Scalr.aliases('role', name)
        <<-ROLEINFO.gsub(/^ {10}/, '')
          ROLE: #{name} (our aliases: #{aliases.empty? ? 'N/A' : aliases.join(', ')})
            Farm role ID:  #{id}
            Scaling:       #{show_scaling}
            Platform:      #{platform_properties.to_s}
            Servers:       #{servers_display.empty? ? 'None' : "\n      " + servers_display.join("\n      ")}
          ROLEINFO
      end

      def servers_running
        servers.find_all {|server| server.running?}
      end

      def show_scaling
        return '' unless scaling_properties && is_scaling
        if is_scaling.to_i > 0
          "YES [Range: #{scaling_properties.min_instances}-#{scaling_properties.max_instances}]"
        else
          "NO"
        end
      end

      #{
      # :id=>"53494", :roleid=>"53532", :name=>"RailsAppServer", :platform=>"ec2", :category=>"Base",
      # :scalingproperties=>{:mininstances=>"1", :maxinstances=>"2"},
      # :platformproperties=>{:instancetype=>"m1.large", :availabilityzone=>nil},
      # :serverset=>{
      #     :item=>[
      #         {:serverid=>"3f1b372a-ac58-43c8-9821-051bca85f240", :externalip=>"54.242.223.213", :internalip=>"10.12.117.155",
      #          :status=>"Terminated", :index=>"1", :scalarizrversion=>"0.18.2", :uptime=>"4160.08", :isdbmaster=>"0",
      #          :platformproperties=>{:instancetype=>"m1.large", :availabilityzone=>"us-east-1c", :amiid=>"ami-cb087ba2", :instanceid=>"i-ee6b058d"}
      #         },
      #         {:serverid=>"57f02c81-6020-408a-8125-eecffa838673", :externalip=>"54.227.127.229", :internalip=>"10.83.45.160",
      #          :status=>"Running", :index=>"1", :scalarizrversion=>"0.18.2", :uptime=>"60.12", :isdbmaster=>"0",
      #          :platformproperties=>{:instancetype=>"m1.large", :availabilityzone=>"us-east-1c", :amiid=>"ami-febcc097", :instanceid=>"i-9944fff1"}
      #         }
      #     ]
      # },
      # :cloudlocation=>"us-east-1", :isscalingenabled=>"1", :scalingalgorithmset=>nil
      #}
    end

    class FarmSummary < StructWithOptions.new(:comments, :id, :name, :status)

      def self.build(data)
        obj = super(data)
        if obj
          obj.status = obj.status.to_i
        end
        obj
      end

      def self.show_items(farms)
        pat = build_pattern(farms, [:id, :name, :status_formatted],
                            '%{id} - %-{name} - %-{status_formatted} - aliases: %s')
        farms.map do |farm|
          aliases = Scalr.aliases('farm', farm.id.to_s)
          sprintf(pat, farm.id, farm.name, farm.status_formatted, aliases.empty? ? 'N/A' : aliases.join(', '))
        end
      end

      def status_formatted
        return 'RUNNING'       if status == 1
        return 'TERMINATED'    if status == 0
        return 'TERMINATING'   if status == 2
        return 'SYNCHRONIZING' if status == 3
        "UNKNOWN - #{status}"
      end
    end

    class LogItem < StructWithOptions.new(:message, :server_id, :severity, :source, :timestamp)
      def self.build(data)
        obj = super(data)
        obj.severity  = obj.severity.to_i
        obj.timestamp = obj.parse_timestamp(obj.timestamp)
        obj
      end

      def self.show_items(items, source = 'all')
        pat = build_pattern(items, [:source], '%s - %-{source} - [Severity: %s]')
        items.map do |item|
          next unless item.matches_source(source)
          message = item.message.nil? ? '' : "\n" + item.message.strip
          source = item.source || 'N/A'
          sprintf(pat, item.timestamp_formatted, source, item.severity_formatted) + message
        end
      end

      def after?(time_to_check)
        timestamp > time_to_check
      end

      def brief
        self.class.show_items([self])
      end

      def identifier
        "SYSTEM #{server_id}-#{timestamp_formatted}"
      end

      def matches_source(match_source)
        match_source && (match_source == 'all' || match_source == '*' || match_source == source || source.nil?)
      end

      def severity_formatted
        return 'DEBUG'   if severity == 1
        return 'INFO'    if severity == 2
        return 'WARNING' if severity == 3
        return 'ERROR'   if severity == 4
        return 'FATAL'   if severity == 5
        "UNKNOWN (#{severity})"
      end

      def timestamp_formatted
        format_timestamp(timestamp)
      end

      def to_s
        self.class.show_items([self])
      end
    end

    class Platform < StructWithOptions.new(:instance_type, :availability_zone)

      def availability_zone_brief
        geography, area, zone = availability_zone.split(/\-/, 3)
        [geography, area, zone.gsub(/\D/, '')].join('-')
      end

      def to_s
        "Instance: #{instance_type || 'n/a'}; Availability: #{availability_zone || 'n/a'}"
      end
    end

    class Scaling < StructWithOptions.new(:min_instances, :max_instances)
    end

    class Script < StructWithOptions.new(:config_variables, :date, :revision)
      def self.build(data)
        obj = super(data)
        if obj
          obj.config_variables = self.translate_array(data[:configvariables], Scalr::ResponseObject::ConfigVariable)
          obj.date = obj.parse_datestamp(obj.date)
        end
        obj
      end

      def self.show_items(script_revisions)
        pat = build_pattern(script_revisions, [:revision], '%s, v%-{revision} - Config: %s')
        script_revisions.map do |rev|
          sprintf(pat, rev.date_formatted, rev.revision, rev.config_variables_formatted('none'))
        end
      end

      def config_variables_formatted(default = nil)
        config_variables.empty? ? default : config_variables.map {|cv| cv.name}.join('; ')
      end

      def date_formatted
        format_timestamp(self.date)
      end

      # [{:revision=>"1", :date=>"2013-06-17 15:50:59", :configvariables=>{:item => [{:name => '...'}]}}
    end

    class ScriptSummary < StructWithOptions.new(:description, :id, :latest_revision, :name)
      def self.show_items(summaries, display_all = false)
        pat = build_pattern(summaries, [:id, :description, :name], '%-{id} %-{name} - %s')
        summaries.map {|summary|
          display_all || summary.ttm? ? sprintf(pat, summary.id, summary.name, summary.description) : nil
        }.compact
      end

      def ttm?
        name.match(/^TTM/)
      end

      # {:id=>"1", :name=>"SVN update",
      #  :description=>"Update a working copy from SVN repository", :latestrevision=>"1"}
    end

    class ScriptLogItem < StructWithOptions.new(:event, :exec_time, :exit_code, :message, :script_name,
                                                :server_id, :severity, :timestamp)
      def self.fields
        super.merge(execexitcode: :exit_code)
      end

      def self.build(data)
        obj = super(data)
        if obj
          obj.exec_time = obj.exec_time.to_f if obj.exec_time
          obj.exit_code = obj.exit_code.to_i if obj.exit_code
          obj.timestamp = obj.parse_timestamp(obj.timestamp)
        end
        obj
      end

      def self.show_items(log_items, expand_script = nil, quiet = true)
        pat = build_pattern(log_items, [:script_name, :exit_code, :exec_time, :event],
                            '%s - %-{script_name} - [Exit: %{exit_code}] [Exec time: %{exec_time}] [From event: %-{event}] [Server: %s]')
        log_items.map do |log_item|
          next unless ! quiet || log_item.failure?
          from_event = log_item.event || 'N/A'
          message = log_item.message.nil? ? '' : log_item.message.strip
          display_message = ! quiet && (log_item.failure? || log_item.script_matches(expand_script))
          sprintf(pat, log_item.timestamp_formatted, log_item.script_name, log_item.exit_code,
                       log_item.exec_time, from_event, log_item.server_id) +
              (display_message ? "\n" + message + "\n" : '')
        end
      end

      def after?(time_to_check)
        timestamp >= time_to_check
      end

      def brief
        self.class.show_items([self])
      end

      def failure?
        !success?
      end

      def identifier
        "SCRIPT #{server_id}-#{script_name}-#{timestamp_formatted}"
      end

      def script_matches(match_script)
        match_script && (match_script == 'all' || match_script == '*' || match_script == script_name)
      end

      def success?
        exit_code == 0
      end

      def timestamp_formatted
        format_timestamp(timestamp)
      end

      def to_s
        self.class.show_items([self], nil, false)
      end
    end

    class Server < StructWithOptions.new(:id, :external_ip, :internal_ip, :status,
                                         :index, :uptime, :platform_properties)
      def self.components
        { platformproperties: {name: :platform_properties, clazz: Scalr::ResponseObject::Platform} }
      end

      def self.fields
        super.merge(serverid: :id)
      end

      def self.build(data)
        obj = super(data)
        if obj
          obj.index = obj.index.to_i if obj.index
        end
        obj
      end

      def self.show_items(servers, role_name = nil)
        index_width = role_name.nil? ? 3 : role_name.length + 3
        pat = build_pattern(servers, [:index, :status, :uptime, :id],
                            "%#{index_width}s - %-{status} - Uptime %{uptime} - %s")
        sorted = servers.sort_by {|info| info.index}
        sorted.map do |server|
          sprintf(pat, server.name(role_name), server.status, server.uptime, server.platform_properties.to_s)
        end
      end

      def name(role_name = nil)
        role_name.nil? ? "##{index}" : "#{role_name}.#{index}"
      end

      def running?
        status == 'Running'
      end

      def terminated?
        status == 'Terminated'
      end
    end

    class SourceItem < StructWithOptions.new(:auth_type, :id, :type, :url)
      def self.as_hash(items)
        Hash[ items.map{|si| [si.id, si.url]} ]
      end
    end

    class Variable < StructWithOptions.new(:name, :value)

      # turn an array of key/value pairs into ::Variable objects, or if the first (and only)
      # argument is a valid file slurp it in and turn each nonblank, noncomment line into
      # a ::Variable object
      def self.read(specs)
        if specs.length == 1 && File.exists?(specs[0])
          File.readlines(specs[0]).map {|line| to_pair(line)}.compact
        else
          specs.map {|entry| to_pair(entry)}.compact
        end
      end

      def self.to_pair(line)
        line = line.chomp
        return nil if line =~ /^\s*#/ || line =~ /^\s*$/
        key, value = line.strip.split( /\s*[\=\:]\s*/, 2)
        new(key.upcase, value)
      end

      def self.show_items(pairs)
        pat = build_pattern(pairs, [:name], '%-{name}: %s')
        pairs.map{|pair| sprintf(pat, pair.name, pair.value)}
      end

      # does case-insensitive comparison to key
      def name_equals?(other_name)
        name.downcase == other_name.downcase
      end

      # applies regex to key, case unmodified (key will always be in upper case though)
      def name_matches?(pattern)
        name.match(pattern)
      end

      def to_s
        "#{name}=#{value}"
      end
    end

  end
end
