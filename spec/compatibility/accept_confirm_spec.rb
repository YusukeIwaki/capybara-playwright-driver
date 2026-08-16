# frozen_string_literal: true

require 'spec_helper'

ACCEPT_CONFIRM_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <button id="delete">Delete</button>
    <div id="status">waiting</div>
    <script>
      document.getElementById('delete').addEventListener('click', () => {
        document.getElementById('status').textContent = confirm('delete item?') ? 'deleted' : 'kept'
      })
    </script>
  </body>
  </html>
HTML

RSpec.describe 'accept_confirm compatibility', sinatra: true do
  before do
    sinatra.get('/confirm') { ACCEPT_CONFIRM_HTML }
  end

  it 'accepts a confirm' do
    visit '/confirm'

    message = accept_confirm('delete item?', wait: 0.5) do
      find('#delete').click
    end

    expect(message).to eq('delete item?')
    expect(find('#status')).to have_text('deleted')
  end
end
