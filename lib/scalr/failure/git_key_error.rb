require 'scalr/server_failure'

module Scalr::Failure
  class GitKeyError < BaseFailure

    def self.pattern
      /\/root\/.ssh\/aws.+id: No such file or directory/
    end

    def description
      <<-DESC.gsub(/^ +/)
        Your farm does not have the git ssh key necessary to checkout code.
        Run the scalr script 'TTMGitDeployKeys' on your farm and retry.
      DESC
    end

    def display_before
      1
    end

    def name
      'No keys for git'
    end

    Scalr::ServerFailure.add_failure_type(self)
  end
end
__END__
/root/.ssh/aws-review_id: No such file or directory
Permission denied (publickey).
fatal: The remote end hung up unexpectedly
/root/.ssh/aws-review_id: No such file or directory
