Bundler.setup
require File.expand_path('../../ftps_driver', __FILE__)

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f }
#RSpec.configure do |config|
#  config.include ReaderSpecHelper
#end
