# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe 'Node#drop', sinatra: true do
  def with_tempfile(content = 'hello')
    Tempfile.create('drop_test') do |f|
      f.write(content)
      f.flush
      yield f
    end
  end

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
    with_tempfile do |f|
      visit '/'
      find('#drop-zone').drop(f.path)
      expect(page).to have_css('.dropped-file', text: "Dropped file: #{File.basename(f.path)}")
    end
  end

  it 'drops multiple files' do
    with_tempfile('aaa') do |a|
      with_tempfile('bbb') do |b|
        visit '/'
        find('#drop-zone').drop(a.path, b.path)
        expect(page).to have_css('.dropped-file', text: "Dropped file: #{File.basename(a.path)}")
        expect(page).to have_css('.dropped-file', text: "Dropped file: #{File.basename(b.path)}")
      end
    end
  end

  it 'drops a Pathname' do
    with_tempfile do |f|
      visit '/'
      find('#drop-zone').drop(Pathname.new(f.path))
      expect(page).to have_css('.dropped-file', text: "Dropped file: #{File.basename(f.path)}")
    end
  end

  it 'drops a string with mime type' do
    visit '/'
    find('#drop-zone').drop('text/plain' => 'Hello from drop')
    expect(page).to have_css('.dropped-string', text: 'Dropped string: text/plain Hello from drop')
  end

  it 'drops multiple strings' do
    visit '/'
    find('#drop-zone').drop('text/plain' => 'Some text', 'text/uri-list' => 'http://example.com')
    expect(page).to have_css('.dropped-string', text: 'Dropped string: text/plain Some text')
    expect(page).to have_css('.dropped-string', text: 'Dropped string: text/uri-list http://example.com')
  end
end
