# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Node#drop', sinatra: true do
  before do
    sinatra.get '/' do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <div id="drop-zone" style="width:200px;height:200px;border:1px solid black;">
            Drop here
          </div>
          <div id="results"></div>
          <script>
            var dropZone = document.getElementById('drop-zone');
            var results = document.getElementById('results');

            dropZone.addEventListener('dragover', function(e) { e.preventDefault(); });
            dropZone.addEventListener('drop', function(e) {
              e.preventDefault();
              var dt = e.dataTransfer;
              if (dt.items) {
                for (var i = 0; i < dt.items.length; i++) {
                  var item = dt.items[i];
                  if (item.kind === 'file') {
                    var file = item.getAsFile();
                    results.innerHTML += '<p class="dropped-file">Dropped file: ' + file.name + '</p>';
                  } else {
                    (function(type) {
                      item.getAsString(function(s) {
                        results.innerHTML += '<p class="dropped-string">Dropped string: ' + type + ' ' + s + '</p>';
                      });
                    })(item.type);
                  }
                }
              }
            });
          </script>
        </body>
        </html>
      HTML
    end
  end

  it 'drops a single file' do
    visit '/'
    target = find('#drop-zone')
    target.drop(File.expand_path('../../Gemfile', __dir__))
    expect(page).to have_css('.dropped-file', text: 'Dropped file: Gemfile')
  end

  it 'drops multiple files' do
    visit '/'
    target = find('#drop-zone')
    target.drop(
      File.expand_path('../../Gemfile', __dir__),
      File.expand_path('../../Rakefile', __dir__)
    )
    expect(page).to have_css('.dropped-file', text: 'Dropped file: Gemfile')
    expect(page).to have_css('.dropped-file', text: 'Dropped file: Rakefile')
  end

  it 'drops a Pathname' do
    visit '/'
    target = find('#drop-zone')
    target.drop(Pathname.new(File.expand_path('../../Gemfile', __dir__)))
    expect(page).to have_css('.dropped-file', text: 'Dropped file: Gemfile')
  end

  it 'drops a string with mime type' do
    visit '/'
    target = find('#drop-zone')
    target.drop('text/plain' => 'Hello from drop')
    expect(page).to have_css('.dropped-string', text: 'Dropped string: text/plain Hello from drop')
  end

  it 'drops multiple strings' do
    visit '/'
    target = find('#drop-zone')
    target.drop('text/plain' => 'Some text', 'text/uri-list' => 'http://example.com')
    expect(page).to have_css('.dropped-string', text: 'Dropped string: text/plain Some text')
    expect(page).to have_css('.dropped-string', text: 'Dropped string: text/uri-list http://example.com')
  end
end
