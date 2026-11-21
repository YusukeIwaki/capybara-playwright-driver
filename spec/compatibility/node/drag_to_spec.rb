# frozen_string_literal: true

require 'spec_helper'

# https://github.com/YusukeIwaki/capybara-playwright-driver/issues/177
# An empty drop zone has no height. Selenium does not treat it as displayed, so it
# is located with `visible: :all` here; once located, Selenium drags onto it.
DRAG_TO_EMPTY_DROP_ZONE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <div id="html5-source" draggable="true" style="width: 30px; height: 30px; background: blue;">FS</div>
    <div id="mouse-source" style="width: 30px; height: 30px; background: green;">MS</div>
    <div id="day-cell" style="width: 200px; height: 100px; background: #eee;">
      <div id="empty-drop-zone"></div>
    </div>
    <div id="status">waiting</div>
    <script>
      const dayCell = document.getElementById('day-cell');
      const status = document.getElementById('status');

      document.getElementById('html5-source').addEventListener('dragstart', function(event) {
        event.dataTransfer.setData('text/plain', 'FS');
      });
      dayCell.addEventListener('dragover', function(event) { event.preventDefault(); });
      dayCell.addEventListener('drop', function(event) {
        event.preventDefault();
        status.textContent = 'dropped';
      });
      dayCell.addEventListener('mouseup', function() {
        status.textContent = 'mouse released';
      });
    </script>
  </body>
  </html>
HTML

RSpec.describe 'Node#drag_to compatibility', sinatra: true do
  before do
    sinatra.get('/') { DRAG_TO_EMPTY_DROP_ZONE_HTML }
    visit '/'
  end

  it 'drops an HTML5 draggable onto an empty drop zone that has no height' do
    find('#html5-source').drag_to(find('#empty-drop-zone', visible: :all))

    expect(page).to have_css('#status', text: 'dropped')
  end

  it 'releases the mouse over an empty drop zone that has no height' do
    find('#mouse-source').drag_to(find('#empty-drop-zone', visible: :all))

    expect(page).to have_css('#status', text: 'mouse released')
  end
end
