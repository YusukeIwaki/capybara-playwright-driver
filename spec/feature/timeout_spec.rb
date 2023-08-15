require 'spec_helper'

RSpec.describe 'timeout', sinatra: true do
  before do
    sinatra.get('/sleep') do
      sleep params[:s].to_i
      'OK'
    end
  end

  around do |example|
    original_wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 1
    example.run
    Capybara.default_max_wait_time = original_wait_time
  end

  it 'does not timeout with driver without timeout option', driver: :playwright do
    visit '/sleep?s=6'
    expect(page).to have_content('OK')
  end

  it 'does timeout when navigation exceeds 30 seconds with driver without timeout option', driver: :playwright do
    expect { visit '/sleep?s=31' }.to raise_error(Playwright::TimeoutError)
  end

  it 'does timeout when navigation exceeds the specified timeout value', driver: :playwright_timeout_2 do
    original_browser_options_value_method = Capybara::Playwright::BrowserOptions.instance_method(:value)
    allow_any_instance_of(Capybara::Playwright::BrowserOptions).to receive(:value) do |instance|
      # force extend the launch timeout for checking if the timeout is used for navigation.
      options = original_browser_options_value_method.bind(instance).call
      options[:timeout] = 30000
      options
    end
    expect { visit '/sleep?s=3' }.to raise_error(Playwright::TimeoutError)
  end

  it "respects the custom default time out", driver: :playwright_timeout_2 do
    visit "/sleep?s=0"

    expect {
      page.driver.with_playwright_page(&:itself).get_by_label('does not exist').text_content
    }.to raise_error(Playwright::TimeoutError, /Timeout 2000ms exceeded/)
  end
end
