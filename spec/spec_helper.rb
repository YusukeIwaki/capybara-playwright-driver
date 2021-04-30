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
end

if ENV['CI']
  def trace(klass)
    klass.public_instance_methods(false).each do |method_sym|
      orig = klass.instance_method(method_sym)
      klass.define_method(method_sym) do |*args, &block|
        puts "START: #{klass.name}##{method_sym}, #{args}"
        orig.bind(self).call(*args, &block)
      end
    end
  end
  trace(Capybara::Playwright::Driver)
  trace(Capybara::Playwright::Node)
end

Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(app,
    playwright_cli_executable_path: ENV['PLAYWRIGHT_CLI_EXECUTABLE_PATH'],
    browser_type: :chromium,
    headless: ENV['CI'] ? true : false,
  )
end

Capybara.default_driver = :playwright
Capybara.save_path = 'tmp/capybara'
Capybara.server = :webrick
