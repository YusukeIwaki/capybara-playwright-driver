# frozen_string_literal: true

require 'spec_helper'

SEND_KEYS_CONTENTEDITABLE_MENTION_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <div id="editor" contenteditable="true">Hello</div>
    <input id="mention-search">
    <script>
      const editor = document.getElementById('editor');
      editor.addEventListener('input', function() {
        if (window.mentionOpened || !this.textContent.includes('@')) return;

        window.mentionOpened = true;
        document.getElementById('mention-search').focus();
      });
    </script>
  </body>
  </html>
HTML

RSpec.describe '#send_keys', sinatra: true do
  before do
    skip if Gem::Version.new(Capybara::VERSION) < Gem::Version.new('3.36.0')

    sinatra.get '/' do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <input type="text" name="form[first_name]" value="John" id="form_first_name" tabindex="1"/>
        </body>
        </html>
      HTML
    end

    sinatra.get('/contenteditable-mention') { SEND_KEYS_CONTENTEDITABLE_MENTION_HTML }
  end

  it 'defaults to sending keys to the active_element' do
    visit '/'

    expect(page.active_element).to match_selector(:css, 'body')

    page.send_keys(:tab)

    expect(page.active_element).to match_selector(:css, '[tabindex="1"]')
  end

  it 'allows the caret position to be explicit after a contenteditable loses focus' do
    visit '/contenteditable-mention'
    editor = find('#editor')
    editor.send_keys(:end)
    editor.send_keys('@')

    expect(page.active_element[:id]).to eq('mention-search')

    editor.send_keys(:end, 'alice')

    expect(editor.text).to eq('Hello@alice')
  end
end
