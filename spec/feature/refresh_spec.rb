require 'spec_helper'

RSpec.describe 'refresh', sinatra: true do
  let(:playwright_page) { page.driver.with_playwright_page { |browser_page| browser_page } }

  before do
    sinatra.get '/refresh' do
      sleep 0.2
      '<h1>Refreshed</h1>'
    end

    sinatra.get '/refresh_with_script' do
      '<script src="/refresh.js"></script>'
    end

    sinatra.get '/refresh.js' do
      sleep 0.2
      content_type 'application/javascript'
      headers 'Cache-Control' => 'no-store'
      'window.scriptLoaded = true'
    end

    sinatra.get '/refresh_with_frame' do
      '<iframe id="child" src="/refresh"></iframe>'
    end

    sinatra.get '/refresh_form' do
      '<form method="post" action="/refresh_submission"><input name="message" value="hello"><button>Submit</button></form>'
    end

    sinatra.post '/refresh_submission' do
      "<body data-method=\"POST\">#{params[:message]}</body>"
    end
  end

  it 'waits for the old document to be replaced' do
    visit '/refresh'
    execute_script 'window.survivor = true'

    refresh

    expect(playwright_page.evaluate('() => window.survivor')).to be_nil
  end

  it 'waits for external scripts to finish loading' do
    visit '/refresh_with_script'
    execute_script 'window.scriptLoaded = false'

    refresh

    expect(playwright_page.evaluate('() => window.scriptLoaded')).to eq(true)
  end

  it 'does not finish on a same-document navigation during reload' do
    visit '/refresh'
    execute_script <<~JAVASCRIPT
      window.survivor = true;
      window.addEventListener('beforeunload', () => {
        history.pushState({}, '', '#reloading');
      });
    JAVASCRIPT

    refresh

    expect(playwright_page.evaluate('() => window.survivor')).to be_nil
  end

  it 'reloads the main document when called within a frame' do
    visit '/refresh_with_frame'
    execute_script 'window.survivor = true'

    within_frame('child') { refresh }

    expect(playwright_page.evaluate('() => window.survivor')).to be_nil
  end

  it 'reloads about:blank without an HTTP response' do
    visit 'about:blank'
    execute_script 'window.survivor = true'

    refresh

    expect(playwright_page.evaluate('() => window.survivor')).to be_nil
  end

  it 'preserves the POST request when reloading a form submission' do
    visit '/refresh_form'
    click_button 'Submit'

    refresh

    expect(playwright_page.evaluate('() => document.body.dataset.method')).to eq('POST')
  end

  it 'respects the configured navigation timeout on Firefox', driver: :playwright_timeout_2_default_timeout_3_default_navigation_timeout_4 do
    skip 'Firefox reload uses an explicit load event waiter' unless ENV['BROWSER'] == 'firefox'

    sinatra.get '/refresh_timeout' do
      sleep 5
      'Refreshed too late'
    end
    visit '/refresh'
    execute_script "history.replaceState({}, '', '/refresh_timeout')"

    expect { refresh }.to raise_error(Playwright::TimeoutError, /Timeout 4000ms/)
  end
end
