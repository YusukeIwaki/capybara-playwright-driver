require 'spec_helper'

RSpec.describe 'Example' do
  it 'take a screenshot' do
    Capybara.app_host = 'https://github.com'
    visit '/YusukeIwaki'
    page.save_screenshot('YusukeIwaki.png')
  end

  it 'search capybara' do
    Capybara.app_host = 'https://github.com'
    visit '/'
    fill_in('q', with: 'Capybara')
    find('a[data-item-type="global_search"]').click
    all('.repo-list-item').each do |li|
      puts li.all('a').first.text
    end
  end
end
