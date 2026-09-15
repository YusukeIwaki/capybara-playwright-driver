# frozen_string_literal: true

require 'spec_helper'

PARAGRAPH_TEXT_HTML = '<div id="message"><p>Hello</p><p>Regards</p></div>'

RSpec.describe 'Node#text', sinatra: true do
  before { sinatra.get('/paragraphs') { PARAGRAPH_TEXT_HTML } }

  it 'follows innerText paragraph spacing' do
    visit '/paragraphs'

    expect(find('#message')).to have_text("Hello\n\nRegards", exact: true)
  end
end
