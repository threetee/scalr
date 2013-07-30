require 'scalr/server_failure'

module Scalr::Failure
  class S3Authentication < BaseFailure
    def description(context=nil)
      config_variables = ['Sorry! Cannot fetch config entries, no :farm_id available.']
      if context && context[:farm_id]
        response = Scalr::Caller.new(:global_variables_list).invoke(context)
        if response
          config_variables = response.content.
              find_all {|pair| pair.name_matches?(/^TTM_AWS_ACCESS/)}.
              map &:to_s
        end
      end
      <<-DESC.gsub(/^\s{8}/, '')
        This occurs when we copy static assets to S3 for it to serve. To fix the problem
        check the validity of these Scalr configuration entries:

        #{config_variables.join("\n          ")}
      DESC
    end

    def name
      'AWS authentication failed during asset precompile.'
    end

    def pattern
      /AWS Access Key Id you provided does not exist in our records/
    end

    Scalr::ServerFailure.add_failure_type(self)
  end
end

__END__
STDERR: /usr/bin/ruby1.9.1 /usr/local/bin/rake assets:precompile:all RAILS_ENV=production RAILS_GROUPS=assets
rake aborted!
Expected(200) <=> Actual(403 Forbidden)
  request => {:connect_timeout=>60,
              :headers=>{"Date"=>"Thu, 18 Jul 2013 18:11:17 +0000",
                         "Authorization"=>"AWS 27BzORCy2yQ04r3ybjSsDvteGjDZPMJzaWyhYPzN:SDBCAAOp4BNPZfddIxIBi7c1nOc=",
                         "Host"=>"ttm-assets.s3.amazonaws.com:443"},
              :instrumentor_name=>"excon",
              :mock=>false,
              :read_timeout=>60,
              :retry_limit=>4,
              :ssl_ca_file=>"/var/lib/gems/1.9.1/gems/excon-0.13.4/data/cacert.pem",
              :ssl_verify_peer=>true,
              :write_timeout=>60,
              :host=>"ttm-assets.s3.amazonaws.com",
              :path=>"/",
              :port=>"443",
              :query=>{"prefix"=>"assets"},
              :scheme=>"https",
              :expects=>200,
              :idempotent=>true,
              :method=>"GET",
              :response_block=>#<Proc:0x000000069d2258@/var/lib/gems/1.9.1/gems/fog-1.3.1/lib/fog/core/connection.rb:16 (lambda)>}
  response => #<Excon::Response:0x00000006da8eb8
                @body="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Error><Code>InvalidAccessKeyId</Code>
                       <Message>The AWS Access Key Id you provided does not exist in our records.</Message>
                       <RequestId>5072BF9CD6D3BC39</RequestId>
                       <HostId>GiVjM/iwRV4XHGPH5Hoj3rxVOf8Aldec5Hy9bpusYzh+Ml4doRZ7ellkmbBE6rsy</HostId>
                       <AWSAccessKeyId>27BzORCy2yQ04r3ybjSsDvteGjDZPMJzaWyhYPzN</AWSAccessKeyId></Error>",
                @headers={"x-amz-request-id"=>"5072BF9CD6D3BC39",
                          "x-amz-id-2"=>"GiVjM/iwRV4XHGPH5Hoj3rxVOf8Aldec5Hy9bpusYzh+Ml4doRZ7ellkmbBE6rsy",
                          "Content-Type"=>"application/xml",
                          "Transfer-Encoding"=>"chunked",
                          "Date"=>"Thu, 18 Jul 2013 18:11:17 GMT",
                          "Server"=>"AmazonS3"},
                @status=403>

