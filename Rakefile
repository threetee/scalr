require "rake"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "scalr/version"

task :gem => :build

desc "builds the scalr gem"
task :build do
  system "gem build scalr.gemspec"
end

desc "builds and installs the scalr gem"
task :install => :build do
  system "sudo gem install scalr-#{Scalr::VERSION}.gem"
end

desc "builds and tags a scalr release using a version number provided in `lib/scalr/version.rb`"
task :release => :build do
  puts "Tagging #{Scalr::VERSION}..."
  system "git tag -a #{Scalr::VERSION} -m 'Tagging #{Scalr::VERSION}'"
  puts "Pushing to Github..."
  system "git push --tags"
  puts "NOT Pushing to rubygems.org because we are a fork"
  #system "gem push scalr-#{Scalr::VERSION}.gem"
end

task :default => :build
