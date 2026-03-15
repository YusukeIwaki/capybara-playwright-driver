require 'spec_helper'

RSpec.describe 'closing a non-current window', sinatra: true do
  before do
    sinatra.get '/' do
      '<h1>Main Page</h1>'
    end

    sinatra.get '/other' do
      '<h1>Other Page</h1>'
    end
  end

  it 'keeps the current page accessible after closing a different window' do
    visit '/'
    expect(page).to have_content('Main Page')

    new_window = open_new_window(:window)
    within_window(new_window) do
      visit '/other'
      expect(page).to have_content('Other Page')
    end

    new_window.close

    # The current page should still be accessible (this fails before the fix)
    expect(page).to have_content('Main Page')
    expect(page.current_url).to include('/')
  end
end
