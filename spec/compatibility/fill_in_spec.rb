# frozen_string_literal: true

require 'spec_helper'
require 'selenium-webdriver'

RSpec.describe 'fill_in compatibility', type: :feature, sinatra: true do
  before do
    sinatra.get '/' do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <label for="body">Body</label>
          <textarea id="body" name="body"></textarea>
          <div id="preview"></div>
          <script>
            body.addEventListener('keyup', function() {
              preview.textContent = body.value;
            });
          </script>
        </body>
        </html>
      HTML
    end
  end

  shared_examples 'keyup-compatible fill_in' do |driver_name|
    it "triggers keyup events with #{driver_name}" do
      Capybara.using_driver(driver_name) do
        visit '/'

        fill_in 'Body', with: 'updated FAQ'

        expect(find(:fillable_field, 'Body').value).to eq('updated FAQ')
        expect(find(:css, '#preview')).to have_text('updated FAQ')
      end
    end
  end

  include_examples 'keyup-compatible fill_in', :selenium_chrome_headless
  include_examples 'keyup-compatible fill_in', :playwright
end
