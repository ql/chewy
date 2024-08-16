require 'bundler'

Bundler.require

require 'active_record'

require 'rspec/its'
require 'rspec/collection_matchers'

require 'timecop'

Kaminari::Hooks.init if defined?(Kaminari::Hooks)

require 'support/fail_helpers'
require 'support/class_helpers'

require 'chewy/rspec'

host = ENV['ES_HOST'] || 'localhost'
port = ENV['ES_PORT'] || 9250
user = ENV['ES_USER'] || 'elastic'
password = ENV.fetch('ES_PASSWORD')

Chewy.settings = {
  host: "https://#{host}:#{port}",
  user: user,
  password: password,
  wait_for_status: 'green',
  index: {
    number_of_shards: 1,
    number_of_replicas: 0
  },
  transport_options: {
    ssl: {
      ca_file: './tmp/http_ca.crt'
    }
  },
  delete_all_enabled: false
}

# Low-level substitute for now-obsolete drop_indices
def drop_indices
  response = Chewy.client.cat.indices
  indices = response.body.lines.map { |line| line.split[2] }
  return if indices.blank?

  Chewy.client.indices.delete(index: indices)
  Chewy.wait_for_status
end

# Chewy.transport_logger = Logger.new(STDERR)

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = :random
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.include FailHelpers
  config.include ClassHelpers
end

require 'support/active_record'
