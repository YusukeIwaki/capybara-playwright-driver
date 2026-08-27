# frozen_string_literal: true

require 'spec_helper'

VISIBLE_TEXT_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <div id="message">Hello<br><br>Regards</div>
  </body>
  </html>
HTML

RSpec.describe 'Node#text compatibility', sinatra: true do
  before { sinatra.get('/') { VISIBLE_TEXT_HTML } }

  it 'preserves a blank line represented by consecutive line breaks' do
    visit '/'

    expect(find('#message')).to have_text("Hello\n\nRegards", exact: true)
  end
end
