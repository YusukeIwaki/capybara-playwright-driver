require 'spec_helper'

RSpec.describe 'assertion', sinatra: true do
  before do
    sinatra.get '/' do
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

    sinatra.get '/working.html' do
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

    sinatra.get '/finish.html' do
      'finish'
    end
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
