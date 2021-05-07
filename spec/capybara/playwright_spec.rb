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
  when /on \/html selector/
    skip 'CSS selector with "/html" is not supported'
  when /should see disabled options as disabled/,
       /should see enabled options in disabled optgroup as disabled/,
       /should see a disabled fieldset as disabled/,
       /in a disabled fieldset/,
       /should be disabled for all elements that are CSS :disabled/,
       /on a disabled option should not select/
    skip 'disbaled? is available only with <button>, <select>, <input> or <textarea> in Playwright'
  when /should offset outside (the|from center of) element/
    skip 'Playwright does not allow to click outside the element'
  when /should not retry clicking when wait is disabled/
    skip 'wait = 0 is not supported'
  when /should support multiple statements via IIFE/
    skip 'evaluateHandle does not work with Array.'
  when /when details is toggled open and closed/
    skip "NoMethodError: undefined method `and' for #<Capybara::RSpecMatchers::Matchers::HaveSelector:0x00007f9bafd56900>"
  when /Playwright node #selected\?/,
       /Playwright node #obscured\?/,
       /Playwright node #drag_to/,
       /Element#drop/,
       /Playwright node #reload/,
       /Playwright node #evaluate_async_script/
    skip 'not implemented'
  end

  Capybara::SpecHelper.reset!

  includes = [ # https://github.com/teamcapybara/capybara/tree/master/lib/capybara/spec/session
    'node_spec.rb',
    'check_spec.rb',
    'uncheck_spec.rb',
    'select_spec.rb',
    'unselect_spec.rb',
    'has_field_spec.rb',
  ]
  if includes.any? { |filename| example.metadata[:file_path].end_with?("/#{filename}") }
    next
  else
    skip
  end
end
