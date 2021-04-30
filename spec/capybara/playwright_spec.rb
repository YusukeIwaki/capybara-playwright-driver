# frozen_string_literal: true

require 'spec_helper'
require 'capybara/spec/spec_helper'

module TestSessions
  Playwright = Capybara::Session.new(:playwright, TestApp)
end

skipped_tests = %i[

]
Capybara::SpecHelper.run_specs TestSessions::Playwright, 'Playwright', capybara_skip: skipped_tests do |example|

end
