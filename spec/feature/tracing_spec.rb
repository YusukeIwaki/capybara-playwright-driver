require 'spec_helper'

RSpec.describe 'tracing', sinatra: true do
  TRACES_DIR = 'tmp/capybara/playwright'.freeze

  before do
    FileUtils.rm_rf(TRACES_DIR)

    sinatra.get '/' do
      <<~HTML
        <!DOCTYPE html>
        <button>Go</button>
      HTML
    end
  end

  it 'can start and stop tracing' do
    page.driver.start_tracing(name: "test_trace", screenshots: true, snapshots: true, sources: true, title: "test_trace")

    visit '/'
    click_on 'Go'
    expect(page).to have_content('Go')

    page.driver.stop_tracing(path: "#{TRACES_DIR}/test_trace.zip")

    expect(File).to exist("#{TRACES_DIR}/test_trace.zip")
  end

  it 'can enable tracing only in the block' do
    page.driver.trace name: "test_trace_with_block", screenshots: true, snapshots: true, sources: true, title: "title", path: "#{TRACES_DIR}/test_trace_with_block.zip" do
      visit '/'
      click_on 'Go'
      expect(page).to have_content('Go')
    end

    expect(File).to exist("#{TRACES_DIR}/test_trace_with_block.zip")
  end

  it 'does not start tracing when no block is given' do
    expect { page.driver.trace }.to raise_error(ArgumentError)

    expect {
      page.driver.start_tracing
      page.driver.stop_tracing
    }.not_to raise_error(Playwright::Error, /Tracing has been already started/)
  end
end
