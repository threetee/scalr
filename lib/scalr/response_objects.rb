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

      def initialize(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        super(*args)
        opts.each_pair{|k, v| self.send "#{k}=", v}
      end
    end

    class Application < StructWithOptions.new(:id, :name, :source_id)
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
        if data[:serverset].nil?
          server_items = []
        else
          server_items = data[:serverset][:item].instance_of?(Array) ? data[:serverset][:item] : [data[:serverset][:item]]
        end
        obj.servers = server_items.map do |server_data|
          #puts "   ...Adding server item: #{server_data.inspect}]"
          Scalr::ResponseObject::Server.build(server_data)
        end
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

    class Platform < StructWithOptions.new(:instance_type, :availability_zone)
    end

    class Scaling < StructWithOptions.new(:min_instances, :max_instances)
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
