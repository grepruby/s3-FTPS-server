require 'rubygems'
require 'bundler'
include Rake::DSL

desc "Run the test_server"
task :test_server do |t|
  system("bundle exec bin/fakes3 --port 10453 --root test_root")
end
