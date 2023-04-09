# frozen_string_literal: true

require 'bundler/setup'
require 'allure-rspec'
require 'capybara/playwright'
require 'capybara/rspec'
require 'rack/test_server'
require 'sinatra/base'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.define_derived_metadata(file_path: %r(/spec/feature/)) do |metadata|
    metadata[:type] = :feature
  end

  config.around(:each, sinatra: true) do |example|
    @sinatra = Class.new(Sinatra::Base)

    test_server = Rack::TestServer.new(
      app: @sinatra,
      server: :webrick,
      Host: '127.0.0.1',
      Port: 4567)

    test_server.start_async
    test_server.wait_for_ready
    Capybara.app_host = 'http://localhost:4567'

    previous_wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 5
    example.run
    Capybara.default_max_wait_time = previous_wait_time

    test_server.stop_async
    test_server.wait_for_stopped
  end

  test_with_sinatra = Module.new do
    attr_reader :sinatra
  end
  config.include(test_with_sinatra, sinatra: true)
end

driver_opts = {
  browser_server_endpoint_url: ENV['BROWSER_SERVER_ENDPOINT_URL'],
  playwright_server_endpoint_url: ENV['PLAYWRIGHT_SERVER_ENDPOINT_URL'],
  playwright_cli_executable_path: ENV['PLAYWRIGHT_CLI_EXECUTABLE_PATH'],
  browser_type: (ENV['BROWSER'] || 'chromium').to_sym,
  headless: ENV['CI'] ? true : false,
}

Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(app, **driver_opts)
end

Capybara.register_driver(:playwright_timeout_5) do |app|
  Capybara::Playwright::Driver.new(app,
    browser_server_endpoint_url: ENV['BROWSER_SERVER_ENDPOINT_URL'],
    playwright_server_endpoint_url: ENV['PLAYWRIGHT_SERVER_ENDPOINT_URL'],
    playwright_cli_executable_path: ENV['PLAYWRIGHT_CLI_EXECUTABLE_PATH'],
    browser_type: (ENV['BROWSER'] || 'chromium').to_sym,
    headless: ENV['CI'] ? true : false,
  )
end

Capybara.default_driver = :playwright
Capybara.save_path = 'tmp/capybara'
Capybara.server = :webrick
