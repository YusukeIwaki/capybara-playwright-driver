# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Session#send_keys compatibility', sinatra: true, text_input: true do
  before do
    skip if Gem::Version.new(Capybara::VERSION) < Gem::Version.new('3.36.0')

    sinatra.get('/') { File.read(File.expand_path('../fixtures/text_input.html', __dir__)) }
    visit '/'
  end

  it 'sends Tab to the active element' do
    page.send_keys(:tab)

    expect(page.active_element[:id]).to eq('first')
  end

  it 'types at the current caret without refocusing the active element' do
    find('#editor').execute_script('this.focus(); getSelection().collapse(this.firstChild, 2)')

    page.send_keys('X')

    expect(find('#editor').text).to eq('HeXllo')
  end

  it 'interprets a tab inside a string and continues in the next field' do
    find('#first').execute_script('this.focus()')

    page.send_keys("\tZ")

    expect(find('#second').value).to eq('Z')
  end
end
