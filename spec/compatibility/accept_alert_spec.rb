# frozen_string_literal: true

require 'spec_helper'

LATE_ALERT_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <button id="assign">Assign</button>
    <script>
      assign.addEventListener('click', () => {
        alert('assigned')
      })
    </script>
  </body>
  </html>
HTML

DELAYED_ALERT_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <button id="assign">Assign</button>
    <script>
      assign.addEventListener('click', () => {
        setTimeout(() => alert('assigned later'), 50)
      })
    </script>
  </body>
  </html>
HTML

RSpec.describe 'accept_alert compatibility', sinatra: true do
  before do
    sinatra.get('/late-alert') { LATE_ALERT_HTML }
    sinatra.get('/delayed-alert') { DELAYED_ALERT_HTML }
  end

  it 'accepts an alert after the alert has already opened' do
    visit '/late-alert'

    find('#assign').click

    expect(accept_alert('assigned', wait: 0.5)).to eq('assigned')
  end

  it 'waits for an alert that opens asynchronously' do
    visit '/delayed-alert'

    find('#assign').click

    expect(accept_alert('assigned later', wait: 1)).to eq('assigned later')
  end
end
