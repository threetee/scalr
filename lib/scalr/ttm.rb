require 'pathname'

module Scalr
  class TTMAliasReader

    DEFAULT_ALIAS_FILE = '~/.ttm_scalr_aliases.json'

    def initialize(alias_file = DEFAULT_ALIAS_FILE)
      @alias_file = alias_file
    end

    # aliases stored in ~/.ttmscalr_aliases as JSON
    # format:
    #   "farm": {
    #     "id": ["name", "name"...]
    #   },
    #   "role": {
    #     "id" : ["name", "name"...]
    #   },
    #   "application": {
    #     "id" : ["name", "name"...]
    #   }...
    def read_aliases
      return {} if Scalr.has_aliases?('farm', 'role', 'application')

      alias_path = File.expand_path(@alias_file)

      unless File.exists?(alias_path)
        $stderr.puts <<-ALIASHELP.gsub(/^\s+/, '')
          You do not currently have a file for scalr aliases.
          Creating one for you now in #{alias_path}...
        ALIASHELP

        File.open(alias_path, 'w') do |out|
          out.puts <<-DEFAULTALIASES.gsub(/^ {12}/, '')
            {
              "farm": {
                "20026": ["Prod-DB", "master"],
                "20027": ["Prod-DB-Enrollments", "enrollments", "shard1"],
                "14498": ["Production", "ttm-production", "prod"],
                "15275": ["Review", "ttm-review", "ttm-staging"],
                "15596": ["RC"],
                "15597": ["lab"],
                "19975": ["DW-production", "DW", "DW-prod", "dw-prod"],
                "15548": ["DW-2013-2014", "DW14", "DW-13-14"],
                "21954": ["DW-2014-2105", "DW15", "DW-14-15"],
                "15971": ["DW-staging", "DW-staging", "dw-staging", "dw-rc"],
                "19801": ["DW-staging-lab", "DW-lab"],
                "20277": ["DW-Staging-Review", "dw-review"],
                "20278": ["DW-Staging-Dev", "dw-dev"],
                "15898": ["Dev"],
                "15944": ["Jenkins"],
                "21876": ["TTM-Jenkins"],
                "19759": ["Solr"],
                "19175": ["MathJS"],
                "20464": ["QA"],
                "20470": ["DW-Staging-QA", "dw-qa"],
                "20175": ["Live-Teaching-Dev", "lt-dev"],
                "20988": ["Live-Teaching-Production", "lt-production", "lt-prod"],
                "20989": ["Live-Teaching-RC", "lt-RC"],
                "20990": ["Live-Teaching-Lab", "lt-lab"],
                "20991": ["Live-Teaching-Review", "lt-review"],
                "20992": ["Live-Teaching-QA", "lt-QA"],
                "22874": ["Login-Production"],
                "22875": ["Login-Dev"],
                "22876": ["Login-RC"],
                "23115": ["Login-Lab"],
                "23063": ["Warehouse-SY1516", "dw-sy1516"]
              },
              "role": {
                "RailsAppServer" : ["rails", "web"],
                "Sidekiq"        : ["sidekiq"],
                "Bunchball"      : ["bunchball", "bb"],
                "SystemWatcher"  : ["watcher"],
                "Reports"        : ["reports"],
                "DevDebug"       : ["debug"],
                "PGSQL-9-2"      : ["pg", "pgsql", "psql"],
                "DataLoad"       : ["dl", "dataload"],
                "Jenkins-Master" : ["JenkinsM", "jenkins", "master"],
                "JenkinsSlave"   : ["jenkinsslave", "slave"],
                "JenkinsMinion"  : ["jenkinsminion","minion"],
                "lb-nginx64-TTM" : ["lb"],
                "NodeAppServer"  : ["node"],
                "Solr"           : ["solr"]

              },
              "application": {
                "968":  ["production", "master"],
                "1204": ["review", "staging"],
                "1242": ["lab", "apangea"],
                "1243": ["rc", "ttm-rc"],
                "1256": ["dw-prod", "dw-production"],
                "1322": ["dw-staging"],
                "1306": ["dev", "dev"]
              }
            }
          DEFAULTALIASES
        end
        $stderr.puts "DONE - file written. Let's go!"
      end
      JSON.parse(IO.read(alias_path))
    end
  end
end

module Scalr
  Scalr.version = '2.3.0'

  Scalr.alias_reader = Scalr::TTMAliasReader.new()

  # @return true if Scalr API credentials available, false if not
  def self.read_access_info
    if ENV['TTM_SCALR_KEY_ID'] && ENV['TTM_SCALR_ACCESS_KEY']
      Scalr.key_id = ENV['TTM_SCALR_KEY_ID']
      Scalr.access_key = ENV['TTM_SCALR_ACCESS_KEY']
    elsif access_file = resolve_access_info_file
      values = Scalr.hash_from_file(access_file)
      Scalr.key_id = values[:key_id]
      Scalr.access_key = values[:access_key]
    end
    [Scalr.key_id, Scalr.access_key].all? {|str| ! str.nil? && str.strip.length > 0}
  end

  def self.hash_from_file(filename)
    raise "File does not exist [Given: #{filename}]" unless File.exists?(filename)
    h = {}
    File.readlines(filename).each do |line|
      key, value = line.strip.split(/\s*=\s*/, 2)
      h[key.downcase.to_sym] = value if key
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
