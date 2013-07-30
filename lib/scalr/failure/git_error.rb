require 'scalr/server_failure'

module Scalr::Failure
  class GitError
    def description
      <<-DESC.gsub()
        We either had a problem checking out and syncing the TTM source
        code, or we had a problem checking out one of the git-referenced
        dependencies from Gemfile.
      DESC
    end

    def display_before
      1
    end

    def name
      'Problem with git'
    end

    def pattern
      /Git error/
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