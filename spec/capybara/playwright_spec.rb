# frozen_string_literal: true

require 'spec_helper'
require 'capybara/spec/spec_helper'

module TestSessions
  Playwright = Capybara::Session.new(:playwright, TestApp)
end

skipped_tests = %i[

]
Capybara::SpecHelper.run_specs TestSessions::Playwright, 'Playwright', capybara_skip: skipped_tests do |example|
  case example.metadata[:full_description]
  when /should offset outside (the|from center of) element/
    pending 'Playwright does not allow to click outside the element'
  when /should not retry clicking when wait is disabled/
    pending 'wait = 0 is not supported'
  when /should support multiple statements via IIFE/
    pending 'evaluateHandle does not work with Array.'
  when /when details is toggled open and closed/
    pending "NoMethodError: undefined method `and' for #<Capybara::RSpecMatchers::Matchers::HaveSelector:0x00007f9bafd56900>"
  when /Playwright node #obscured\?/,
       /Playwright node #drag_to/,
       /Element#drop/,
       /Playwright node #evaluate_async_script/
    pending 'not implemented'
  end

  Capybara::SpecHelper.reset!

  includes = [ # https://github.com/teamcapybara/capybara/tree/master/lib/capybara/spec/session
    'node_spec.rb',
    'check_spec.rb',
    'uncheck_spec.rb',
    'choose_spec.rb',
    'select_spec.rb',
    'unselect_spec.rb',
    'find_field_spec.rb',
    'has_field_spec.rb',
    'body_spec.rb',
    'click_button_spec.rb',
    'click_link_or_button_spec.rb',
    'click_link_spec.rb',
    'go_back_spec.rb',
    'go_forward_spec.rb',
    'accept_alert_spec.rb',
    'accept_confirm_spec.rb',
    'accept_prompt_spec.rb',
    'dismiss_confirm_spec.rb',
    'dismiss_prompt_spec.rb',
    'reset_session_spec.rb',
  ]
  if includes.any? { |filename| example.metadata[:file_path].end_with?("/#{filename}") }
    next
  else
    skip
  end
end
