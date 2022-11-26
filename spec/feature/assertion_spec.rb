require 'spec_helper'
require 'rack/test_server'
require 'sinatra/base'

RSpec.describe 'assertion' do
  around do |example|
    app = Class.new(Sinatra::Base) do
      get '/' do
        <<~HTML
        <!DOCTYPE html>
        <h1>click the go button</h1>
        <script>
          function go (btn) {
            btn.disabled = true
            btn.innerText = 'please wait...'
            setTimeout(() => {
              window.location.href = '/working.html?wait=3'
            }, 500)
          }
        </script>
        <button onclick="go(this)">go</button>
        HTML
      end

      get '/working.html' do
        <<~HTML
        working
        <script>
          const wait = +new URLSearchParams(window.location.search).get('wait') || 3
          document.write(`[${wait}]`)
          setTimeout(() => {
            if (wait > 1) {
              window.location.href = '?wait=' + (wait - 1)
            } else {
              window.location.href = '/finish.html'
            }
          }, 300)
        </script>
        HTML
      end

      get '/finish.html' do
        'finish'
      end
    end

    @server = Rack::TestServer.new(
      app: app,
      server: :webrick,
      Host: '127.0.0.1',
      Port: 4567)

    @server.start_async
    @server.wait_for_ready
    Capybara.app_host = 'http://localhost:4567'

    previous_wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 5
    example.run
    Capybara.default_max_wait_time = previous_wait_time

    @server.stop_async
    @server.wait_for_stopped
  end

  it 'survives against navigation' do
    visit '/'

    click_on 'go'
    expect(page).to have_content('finish')
  end

  it 'survives against navigation with refresh' do
    visit '/'

    click_on 'go'
    sleep 0.5
    refresh
    expect(page).to have_content('finish')
  end
end
