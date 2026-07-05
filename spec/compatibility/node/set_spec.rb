# frozen_string_literal: true

require 'spec_helper'

SET_TAB_KEY_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <label for="tag">Tag</label>
    <input id="tag" name="tag">
    <div id="status">waiting</div>
    <script>
      tag.addEventListener('keydown', function(event) {
        if (event.key === 'Tab') {
          event.preventDefault();
          document.getElementById('status').textContent = 'tabbed:' + tag.value;
          alert('tab was pressed');
        }
      });
    </script>
  </body>
  </html>
HTML

RSpec.describe 'Node#set compatibility', sinatra: true do
  before { sinatra.get('/tab-key') { SET_TAB_KEY_HTML } }

  it 'presses Tab instead of inserting a literal tab' do
    visit '/tab-key'

    message = accept_alert('tab was pressed', wait: 0.5) do
      find('#tag').set("bad tag\t")
    end

    expect(message).to eq('tab was pressed')
    expect(find('#status')).to have_text('tabbed:bad tag')
    expect(find('#tag').value).to eq('bad tag')
  end
end
