# frozen_string_literal: true

require 'spec_helper'
require 'capybara/spec/spec_helper'

module TestSessions
  Playwright = Capybara::Session.new(:playwright, TestApp)
end

Capybara::SpecHelper.run_specs TestSessions::Playwright, 'Playwright' do |example|
  case example.metadata[:full_description]
  when /should offset outside (the|from center of) element/
    pending 'Playwright does not allow to click outside the element'
  when /should not retry clicking when wait is disabled/
    pending 'wait = 0 is not supported'
  when /should support multiple statements via IIFE/
    pending 'evaluateHandle does not work with Array.'
  when /when details is toggled open and closed/
    pending "NoMethodError: undefined method `and' for #<Capybara::RSpecMatchers::Matchers::HaveSelector:0x00007f9bafd56900>"
  when /Playwright node #drag_to/,
       /Element#drop/
    pending 'not implemented'
  when /Playwright Capybara::Window#maximize/,
       /Playwright Capybara::Window#fullscreen/
    skip 'not supported in Playwright driver'
  when /Playwright #has_field with validation message/
    # HTML5 validation message is a bit different.
    #  expected: /match the requested format/
    #  obserbed: "Match the requested format"
    pending 'HTML5 validation message is a bit different.' if ENV['BROWSER'] == 'webkit'
  end

  Capybara::SpecHelper.reset!
end
