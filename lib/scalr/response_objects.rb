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
        obj.servers = self.translate_array(data[:serverset], Scalr::ResponseObject::Server)
        obj
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

    class LogItem < StructWithOptions.new(:message, :server_id, :severity, :source, :timestamp)
      def self.build(data)
        obj = super(data)
        obj.timestamp = obj.parse_timestamp(obj.timestamp)
        obj
      end

      def matches_source(match_source)
        match_source && (match_source == 'all' || match_source == '*' || match_source == source || source.nil?)
      end

      def timestamp_formatted
        format_timestamp(timestamp)
      end
    end

    class Platform < StructWithOptions.new(:instance_type, :availability_zone)
    end

    class Scaling < StructWithOptions.new(:min_instances, :max_instances)
    end

    class Script < StructWithOptions.new(:config_variables, :date, :revision)
      def self.build(data)
        obj = super(data)
        obj.config_variables = self.translate_array(data[:configvariables], Scalr::ResponseObject::ConfigVariable)
        obj.date = obj.parse_datestamp(obj.date)
        obj
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
        obj.exec_time = obj.exit_code.to_f if obj.exec_time
        obj.exit_code = obj.exit_code.to_i if obj.exit_code
        obj.timestamp = obj.parse_timestamp(obj.timestamp)
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

    class Server < StructWithOptions.new(:server_id, :external_ip, :internal_ip, :status,
                                         :index, :uptime, :platform_properties)
      def self.components
        { platformproperties: {name: :platform_properties, clazz: Scalr::ResponseObject::Platform} }
      end

      def self.build(data)
        obj = super(data)
        obj.index = obj.index.to_i if obj.index
        obj
      end
    end

  end
end
