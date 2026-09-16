# frozen_string_literal: true

require 'spec_helper'

LINE_BREAK_TEXT_HTML = '<div id="message">Hello<br><br>Regards</div>'
TEXTAREA_TEXT_HTML = "<textarea id=\"message\">Hello\n\nRegards</textarea>"
SVG_TEXT_HTML = "<svg id=\"message\"><text>Hello</text>\n\n<text>Regards</text></svg>"

RSpec.describe 'Node#text compatibility', sinatra: true do
  before do
    sinatra.get('/line-breaks') { LINE_BREAK_TEXT_HTML }
    sinatra.get('/textarea') { TEXTAREA_TEXT_HTML }
    sinatra.get('/svg') { SVG_TEXT_HTML }
  end

  it 'preserves a blank line represented by consecutive line breaks' do
    visit '/line-breaks'

    expect(find('#message')).to have_text("Hello\n\nRegards", exact: true)
  end

  it 'normalizes consecutive line breaks when requested' do
    visit '/line-breaks'

    expect(find('#message')).to have_text('Hello Regards', exact: true, normalize_ws: true)
  end

  it 'preserves a blank line in a textarea' do
    visit '/textarea'

    expect(find('#message')).to have_text("Hello\n\nRegards", exact: true)
  end

  it 'does not expose an SVG source blank line' do
    visit '/svg'

    expect(find('#message')).to have_text("Hello\nRegards", exact: true)
  end
end
