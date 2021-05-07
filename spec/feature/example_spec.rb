require 'spec_helper'

RSpec.describe 'Example' do
  around do |example|
    previous_wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 15
    example.run
    Capybara.default_max_wait_time = previous_wait_time
  end

  it 'take a screenshot' do
    Capybara.app_host = 'https://github.com'
    visit '/YusukeIwaki'
    page.save_screenshot('YusukeIwaki.png')
  end

  it 'search capybara' do
    Capybara.app_host = 'https://github.com'
    visit '/'
    fill_in('q', with: 'Capybara')

    ## [REMARK] Use Playwright-native Page instead of flaky Capybara's selector/action.
    # find('a[data-item-type="global_search"]').click
    page.driver.with_playwright_page do |page|
      page.click('a[data-item-type="global_search"]')
    end

    all('.repo-list-item').each do |li|
      puts "#{li.all('a').first.text} by Capybara"
      puts "#{li.with_playwright_element_handle { |handle| handle.query_selector('a').text_content }} by Playwright"
    end
  end
end
