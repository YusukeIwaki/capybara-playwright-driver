# frozen_string_literal: true

require 'spec_helper'
require 'capybara/spec/spec_helper'

module TestSessions
  Playwright = Capybara::Session.new(:playwright, TestApp)
end

Capybara::SpecHelper.run_specs TestSessions::Playwright, 'Playwright' do |example|
  # example:
  #  CAPYBARA_SPEC_FILTER=shadow_root bundle exec rspec spec/capybara/playwright_spec.rb
  if ENV['CAPYBARA_SPEC_FILTER']
    # Skip all tests that are not matching with the filter
    skip unless example.metadata[:full_description].include?(ENV['CAPYBARA_SPEC_FILTER'])
  end

  case example.metadata[:full_description]
  when /should offset outside (the|from center of) element/
    pending 'Playwright does not allow to click outside the element'
  when /should not retry clicking when wait is disabled/
    pending 'wait = 0 is not supported'
  when /when details is toggled open and closed/
    pending "NoMethodError: undefined method `and' for #<Capybara::RSpecMatchers::Matchers::HaveSelector:0x00007f9bafd56900>"
  when /Element#drop/
    pending 'not implemented'
  when /drag_to.*HTML5/
    skip 'not supported yet in Playwright driver'
  when /Playwright Capybara::Window#maximize/,
       /Playwright Capybara::Window#fullscreen/
    skip 'not supported in Playwright driver'
  when /Playwright #has_field with validation message/
    # HTML5 validation message is a bit different.
    #  expected: /match the requested format/
    #  observed: "Match the requested format"
    pending 'HTML5 validation message is a bit different.' if ENV['BROWSER'] == 'webkit'
  when /Playwright #refresh it reposts/
    # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/spec/selenium_spec_safari.rb#L62
    pending "WebKit opens an alert that can't be closed" if ENV['BROWSER'] == 'webkit'
  when /shadow_root should produce error messages when failing/
    pending "Probably Capybara would assume only Selenium driver."
  when /fill_in should handle carriage returns with line feeds in a textarea correctly/
    # https://github.com/teamcapybara/capybara/commit/a9dd889b640759925bd04c4991de086160242fae#diff-b62b86ae4de5582bd37146266622e3debbdcab6bab6e95f522185c6a4269067dR82
    pending "Not sure what firefox is doing here" if ENV['BROWSER'] == 'firefox'
  when /#has_element\? should be true if the given element is on the page/
    pending 'https://github.com/teamcapybara/capybara/pull/2751'
  end

  Capybara::SpecHelper.reset!
end
