require 'spec_helper'

RSpec.describe 'attach file' do
  before do
    visit 'about:blank'
    page.driver.with_playwright_page do |page|
      page.content = '<input type="file" />'
    end
  end

  it 'should accept String' do
    find('input').set(File.join('./', 'Gemfile'))
  end

  it 'should accept File' do
    find('input').set(File.new('./Gemfile'))
  end

  it 'should accept Pathname' do
    find('input').set(Pathname.new('./').join('Gemfile'))
  end
end
