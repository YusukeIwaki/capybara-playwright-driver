# frozen_string_literal: true

require 'bundler/setup'
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

  config.before(:suite) do
    Capybara.register_driver(:playwright) do |app|
      Capybara::Playwright::Driver.new(app, browser_type: :firefox, headless: false)
    end
    Capybara.default_max_wait_time = 15
    Capybara.default_driver = :playwright
    Capybara.save_path = 'tmp/capybara'
  end
end
