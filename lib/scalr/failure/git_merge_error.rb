require 'scalr/server_failure'

module Scalr::Failure
  class GitMergeError < BaseFailure
    def self.pattern
      /Your local changes to the following files would be overwritten by merge/
    end

    def description(context)
      <<-DESC.gsub(/^ {8}/, '')
        The git repository on the server is out of date with the repository on github. Maybe
        someone has been DOING IT LIVE? You should be able to fix it by fixing git:

          local-$ ttmscalr ssh #{context[:server].name} -f YOUR-FARM
          scalr-# cd /var/www
          scalr-# git reset HEAD --hard
          scalr-# exit

        and then either redeploying the app via the command-line (which will do so for all 
        roles and servers) or redeploying via the GUI:

          - Open https://my.scalr.com/#/dm/tasks/view
          - Find the task with ID #{context[:task].id}; it should have status 'failed'
          - In that row, click the 'Actions' dropdown in the far right
          - Click on 'Re-deploy'
      DESC
    end

    def name
      'Git repository on scalr server out of date'
    end

    Scalr::ServerFailure.add_failure_type(self)
  end
end
__END__
Updating Gems
Fetching source index from https://rubygems.org/
    Fetching git://github.com/thinkthroughmath/omniauth-clever.git
Fetching git@github.com:thinkthroughmath/scalr.git
Git error: command `git clone 'git@github.com:thinkthroughmath/scalr.git'
"/var/lib/gems/1.9.1/cache/bundler/git/scalr-bac276b8bc7dbf012b2755c7838bf2687115e186"
--bare --no-hardlinks` in directory /var/www has failed.
Bundle install failed
