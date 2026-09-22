# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'evaluate_script', sinatra: true do
  before do
    sinatra.get('/') { '<p>Hello</p>' }
    visit '/'
  end

  it 'returns nil for null' do
    expect(page.evaluate_script('null')).to be_nil
  end

  it 'returns nil for undefined' do
    expect(page.evaluate_script('undefined')).to be_nil
  end

  it 'returns nil for null in an object' do
    expect(page.evaluate_script('{ a: null }')).to eq('a' => nil)
  end

  it 'returns nil for null in an array' do
    expect(page.evaluate_script('[null, 1]')).to eq([nil, 1])
  end

  it 'returns nil for null in a nested object' do
    expect(page.evaluate_script('{ a: { b: null } }')).to eq('a' => { 'b' => nil })
  end
end
