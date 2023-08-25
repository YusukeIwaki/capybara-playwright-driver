require 'spec_helper'

RSpec.describe 'timeout', sinatra: true do
  before do
    sinatra.get('/sleep') do
      sleep params[:s].to_i
      'OK'
    end
    sinatra.get('/ng_to_ok') do
      <<~HTML
      <body>
      NG
      </body>
      <script type="text/javascript">
      setTimeout(() => {
        document.body.innerHTML = 'OK'
      }, #{(params[:s] || 1).to_i * 1000})
      </script>
      HTML
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

  it 'does timeout respecting default_navigation_timeout option', driver: :playwright_timeout_2_default_timeout_3_default_navigation_timeout_4 do
    visit '/sleep?s=3'
    expect(page).to have_content('OK')
  end

  it "respects the custom default time out", driver: :playwright_timeout_2_default_timeout_3 do
    visit "/ng_to_ok?s=5"

    page.driver.with_playwright_page do |playwright_page|
      expect {
        playwright_page.get_by_text('OK').text_content
      }.to raise_error(Playwright::TimeoutError, /Timeout 3000ms exceeded/)
    end

    visit "/ng_to_ok?s=2"

    page.driver.with_playwright_page do |playwright_page|
      expect(playwright_page.get_by_text('OK').text_content).to eq('OK')
    end
  end
end
