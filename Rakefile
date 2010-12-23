require "rake"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "scalr/version"

task :gem => :build
task :build do
  system "gem build scalr.gemspec"
end

task :install => :build do
  system "sudo gem install scalr-#{Scalr::VERSION}.gem"
end

task :release => :build do
  puts "Tagging #{Scalr::VERSION}..."
  system "git tag -a #{Scalr::VERSION} -m 'Tagging #{Scalr::VERSION}'"
  puts "Pushing to Github..."
  system "git push --tags"
  puts "Pushing to rubygems.org..."
  system "gem push scalr-#{Scalr::VERSION}.gem"
end

task :default => :build
