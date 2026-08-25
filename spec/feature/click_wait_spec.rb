require 'spec_helper'

RSpec.describe 'click wait options' do
  it 'passes a numeric wait to the Playwright action' do
    visit 'about:blank'
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.content = '<button id="button">Click</button>'
    end
    playwright_timeout = nil
    allow_any_instance_of(Playwright::ElementHandle).to receive(:click).and_wrap_original do |method, **options|
      playwright_timeout = options[:timeout]
      method.call(**options)
    end

    find('#button').click(wait: 0.1)

    expect(playwright_timeout).to eq(100)
  end

  it 'does not pass Playwright wait options to RackTest' do
    app = lambda do |environment|
      body = environment['PATH_INFO'] == '/clicked' ? 'Clicked' : '<a id="link" href="/clicked">Click</a>'
      [200, { 'Content-Type' => 'text/html' }, [body]]
    end
    rack_test_session = Capybara::Session.new(:rack_test, app)
    rack_test_session.visit('/')

    rack_test_session.find('#link').click(wait: 0.1)

    expect(rack_test_session.current_path).to eq('/clicked')
  end
end
