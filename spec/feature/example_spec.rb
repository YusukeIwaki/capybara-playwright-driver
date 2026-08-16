require 'spec_helper'
require 'tmpdir'

RSpec.describe 'Example' do
  around do |example|
    previous_wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 15
    example.run
    Capybara.default_max_wait_time = previous_wait_time
  end

  if ENV['CI']
    before do |example|
      Capybara.current_session.driver.on_save_screenrecord do |video_path|
        next unless defined?(Allure)

        Allure.add_attachment(
          name: "screenrecord - #{example.description}",
          source: File.read(video_path),
          type: Allure::ContentType::WEBM,
          test_case: true,
        )
      end

      Capybara.current_session.driver.on_save_trace do |trace_path|
        next unless defined?(Allure)

        Allure.add_attachment(
          name: "trace - #{example.description}",
          source: File.read(trace_path),
          type: 'application/zip',
          test_case: true,
        )
      end
    end
  end

  it 'take a screenshot' do
    Capybara.app_host = 'https://github.com'
    visit '/YusukeIwaki'
    expect(status_code).to eq(200)
    page.save_screenshot('YusukeIwaki.png')
  end

  it 'can download file' do
    Capybara.app_host = 'https://github.com'
    Dir.mktmpdir do |dir|
      Capybara.save_path = File.join(dir, 'foo', 'bar')
      visit '/YusukeIwaki/capybara-playwright-driver'

      page.driver.with_playwright_page do |page|
        page.locator('button', hasText: 'Code').click
        download = page.expect_download do
          page.click('text=Download ZIP')
        end
        output_path = File.join(dir, 'foo', 'bar', download.suggested_filename)
        sleep 1 # wait for save complete
        expect(File.exist?(output_path)).to eq(true)
      end

      expect(File.exist?(File.join(dir, 'foo', 'bar', 'capybara-playwright-driver-main.zip'))).to eq(true)
    end
  end

  it 'search capybara' do
    Capybara.app_host = 'https://github.com'
    visit '/'
    expect(status_code).to eq(200)

    find('button[aria-label^="Search or jump to"]').click
    search_field = find('input[aria-label="Search or jump to"]')
    search_field.fill_in(with: 'Capybara')
    search_field.send_keys(:enter)

    all('[data-testid="results-list"] h3').each do |li|
      puts "#{li.all('a').first.text} by Capybara"
    end
  end

  it 'search capybara using Playwright-native selector and action' do
    Capybara.app_host = 'https://github.com'
    visit '/'
    find('button[aria-label^="Search or jump to"]').click
    find('input[aria-label="Search or jump to"]').fill_in(with: 'Capybara')

    page.driver.with_playwright_page do |page|
      page.get_by_label('Search or jump to', exact: true).press('Enter')
    end

    all('[data-testid="results-list"] h3').each do |li|
      puts "#{li.with_playwright_element_handle { |handle| handle.text_content }} by Playwright"
    end
  end

  context 'send_keys' do
    it 'can send keys without modifier' do
      Capybara.app_host = 'https://github.com'
      visit '/'

      find('body').send_keys ['/']

      expect(page).to have_css('input[aria-label="Search or jump to"]')
    end

    it 'can send keys with modifier' do
      Capybara.app_host = 'https://tailwindcss.com/'
      visit '/'

      find('body').send_keys [:control, 'k']

      expect(page).to have_field('docsearch-input')
    end

    it 'can shift+modifier' do
      Capybara.app_host = 'https://github.com'
      visit '/'

      expect_any_instance_of(Playwright::ElementHandle).to receive(:press).with('Shift+Home')

      find('body').send_keys %i[shift home]
    end
  end

  it 'does not silently pass when browser has not been started' do
    expect do
      page.driver.with_playwright_page do |_page|
        raise 'this block actually executed'
      end
    end.to raise_error(RuntimeError, 'this block actually executed')
  end
end
