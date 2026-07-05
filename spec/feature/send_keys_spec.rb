# frozen_string_literal: true

require 'spec_helper'

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
  end

  it 'defaults to sending keys to the active_element' do
    visit '/'

    expect(page.active_element).to match_selector(:css, 'body')

    page.send_keys(:tab)

    expect(page.active_element).to match_selector(:css, '[tabindex="1"]')
  end
end
