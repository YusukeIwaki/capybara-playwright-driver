# frozen_string_literal: true

require 'bundler/setup'
require 'allure-rspec'
require 'capybara/playwright'
require 'capybara/rspec'

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
end

Capybara.register_driver(:playwright) do |app|
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
