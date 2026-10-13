# frozen_string_literal: true

require 'spec_helper'

NAVIGATION_STALE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <div id="a">First</div>
    <button id="btn" type="button">Press</button>
    <input id="field" type="text" value="">
    <select id="sel" multiple><option>1</option></select>
  </body>
  </html>
HTML

NAVIGATION_STALE_OTHER_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <p>Other page</p>
  </body>
  </html>
HTML

RSpec.describe 'Node navigation stale compatibility', sinatra: true do
  before do
    sinatra.get('/') { NAVIGATION_STALE_HTML }
    sinatra.get('/other') { NAVIGATION_STALE_OTHER_HTML }
  end

  def expect_invalid_element_error
    yield
    raise RSpec::Expectations::ExpectationNotMetError, 'expected an invalid element error but nothing was raised'
  rescue RSpec::Expectations::ExpectationNotMetError
    raise
  rescue StandardError => e
    translated = page.driver.invalid_element_errors.any? { |error_class| e.is_a?(error_class) }
    expect(translated).to be(true), "expected #{e.class}: #{e.message} to be in invalid_element_errors"
  end

  it 'raises an invalid element error for tag_name after navigation' do
    visit '/'
    node = find('#a')
    visit '/other'

    expect_invalid_element_error { node.base.tag_name }
  end

  it 'raises an invalid element error for disabled? after navigation' do
    visit '/'
    node = find('#btn')
    visit '/other'

    expect_invalid_element_error { node.base.disabled? }
  end

  it 'raises an invalid element error for readonly? after navigation' do
    pending('Selenium swallows StaleElementReferenceError in Node#[] and returns nil') unless page.driver.is_a?(Capybara::Playwright::Driver)

    visit '/'
    node = find('#field')
    visit '/other'

    expect_invalid_element_error { node.base.readonly? }
  end

  it 'raises an invalid element error for multiple? after navigation' do
    pending('Selenium swallows StaleElementReferenceError in Node#[] and returns nil') unless page.driver.is_a?(Capybara::Playwright::Driver)

    visit '/'
    node = find('#sel')
    visit '/other'

    expect_invalid_element_error { node.base.multiple? }
  end

  it 'raises an invalid element error for == after navigation' do
    pending('Selenium compares element ids without touching the browser') unless page.driver.is_a?(Capybara::Playwright::Driver)

    visit '/'
    first = find('#a')
    second = find('#a')
    visit '/other'

    expect_invalid_element_error { first.base == second.base }
  end

  it 'degrades inspect to Obsolete after navigation' do
    visit '/'
    node = find('#a')
    visit '/other'

    expect(node.inspect).to eq('Obsolete #<Capybara::Node::Element>')
  end
end
