# frozen_string_literal: true

require 'spec_helper'

CONTENTEDITABLE_MENTION_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <div id="editor" contenteditable="true" role="textbox" aria-label="Message">Hello</div>
    <input id="mention-search" aria-label="Mention search">
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

RSpec.describe 'send_keys compatibility', sinatra: true do
  before { sinatra.get('/contenteditable-mention') { CONTENTEDITABLE_MENTION_HTML } }

  it 'continues typing at the end of a contenteditable after an autocomplete takes focus' do
    visit '/contenteditable-mention'
    editor = find('#editor')
    editor.click
    editor.send_keys(:end)
    editor.send_keys('@')
    editor.send_keys('alice')

    expect(editor.text).to eq('Hello@alice')
  end
end
