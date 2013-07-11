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

        #puts "Building #{self.name} from #{data.inspect}"

        params = {}
        self.components.each do |k, info|
          component_data = data.nil? || data[k].nil? ? {} : data[k]
          #puts "Generating component: [Old: #{k}] [New: #{info.inspect}] [With data: #{component_data.inspect}]"
          params[info[:name]] = info[:clazz].build(component_data)
          #puts "   ...assigned value: [Data: #{params[info[:name]]}]"
        end

        self.fields.each do |k,v|
          next if params[v] # don't overwrite components
          #puts "Generating pair: [Old: #{k}] [New: #{v}]"
          #puts "   ...assigned value: [Data: #{data[k]}]"
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
        Hash[ keys.map {|key| [key, items.map {|item| item[key].nil? ? 0 : item_length(item[key]) }.max ]} ]
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
    end

    class ConfigVariable < StructWithOptions.new(:name)
    end

    class DeploymentTaskItem < StructWithOptions.new(:server_id, :task_id, :farm_role_id, :remote_path, :status)
      def self.fields
        super.merge(deploymenttaskid: :task_id)
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

      # 'server_spec' could be an index (1), or role.index (rails.1)
      # will return a ::Server object if matching or nil (if not found)
      def find_server(server_spec)
        index = -1
        if match_info = server_spec.match(/^(\w+)\.(\d+)$/)
          role_name = match_info[1]
          index = match_info[2].to_i if Scalr.is_alias?('role', name, role_name)
        elsif server_spec.match(/^\d+$/)
          index = server_spec.to_i
        end

        return nil if index == -1

        matching = servers.find_all {|server| index == server.index}
        if matching.length > 1
          matching = matching.find {|server| server.running?}
        end
        matching.empty? ? nil : matching.first
      end

      def for_display
        servers_display = servers.empty? ? ['None'] : Scalr::ResponseObject::Server.show(servers)
        aliases = Scalr.aliases('role', name)
        <<-ROLEINFO.gsub(/^ {10}/, '')
          ROLE: #{name} (our aliases: #{aliases.empty? ? 'N/A' : aliases.join(', ')})
            Farm role ID:  #{id}
            Scaling:       #{show_scaling}
            Platform:      #{platform_properties.to_s}
            Servers:       #{servers_display.empty? ? 'None' : "\n      " + servers_display.join("\n      ")}
          ROLEINFO
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

      def self.show(farms)
        pat = build_pattern(farms, [:id, :name, :status],
                            '%{id} - %-{name} - %-{status} - aliases: %s')
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

      def self.show(script_revisions)
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
      def self.show(summaries, display_all = false)
        pat = build_pattern(summaries, [:id, :description, :name], '%-{id} %-{name} - %s')
        summaries.map do |summary|
          next unless display_all || summary.ttm?
          sprintf(pat, summary.id, summary.name, summary.description)
        end
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
          obj.exec_time = obj.exit_code.to_f if obj.exec_time
          obj.exit_code = obj.exit_code.to_i if obj.exit_code
          obj.timestamp = obj.parse_timestamp(obj.timestamp)
        end
        obj
      end

      def failure?
        !success?
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

      def self.show(servers)
        pat = build_pattern(servers, [:index, :status, :uptime, :id],
                            '#%-{index}. %{status} - Uptime %{uptime} - %{id} - %s')
        servers.
            sort_by {|info| info.index}.
            map {|server| sprintf(pat, server.index, server.status, server.uptime, server.id, server.platform_properties.to_s)}
      end

      def running?
        status == 'Running'
      end

      def terminated?
        status == 'Terminated'
      end
    end

    class SourceItem < StructWithOptions.new(:auth_type, :id, :type, :url)
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

      def self.show(pairs)
        pat = build_pattern(pairs, [:name], '%-{name}: %s')
        pairs.map{|pair| sprintf(pat, pair.name, pair.value)}
      end

      # does case-insensitive comparison to key
      def key_equals?(other_name)
        name.downcase == other_name.downcase
      end

      # applies regex to key, case unmodified (key will always be in upper case though)
      def key_matches?(pattern)
        name.match(pattern)
      end

      def to_s
        "#{name}=#{value}"
      end
    end

  end
end
