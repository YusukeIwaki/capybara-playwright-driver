# frozen_string_literal: true

require 'spec_helper'
require 'selenium-webdriver'

SET_COMPATIBILITY_DRIVERS = ENV.fetch('COMPATIBILITY_DRIVER', 'selenium_chrome_headless,playwright')
                               .split(',')
                               .map(&:strip)
                               .map(&:to_sym)

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

RSpec.shared_examples 'tab-compatible set' do |driver_name|
  it "presses Tab instead of inserting a literal tab with #{driver_name}" do
    Capybara.using_driver(driver_name) do
      visit '/tab-key'

      message = accept_alert('tab was pressed', wait: 0.5) do
        find('#tag').set("bad tag\t")
      end

      expect(message).to eq('tab was pressed')
      expect(find('#status')).to have_text('tabbed:bad tag')
      expect(find('#tag').value).to eq('bad tag')
    end
  end
end

RSpec.describe 'Node#set compatibility', type: :feature, sinatra: true do
  before { sinatra.get('/tab-key') { SET_TAB_KEY_HTML } }

  SET_COMPATIBILITY_DRIVERS.each do |driver_name|
    include_examples 'tab-compatible set', driver_name
  end
end
