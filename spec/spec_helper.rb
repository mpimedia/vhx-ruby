require 'vhx'
require 'json'
require 'webmock/rspec'

FakeResponse = Struct.new(:body)

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end
