require 'spec_helper'

module ResponseCallbackDelayPatch
  class << self
    attr_accessor :enabled
  end
  self.enabled = false

  def perform_event_emitter_callback(event, callback, args)
    if ResponseCallbackDelayPatch.enabled && event == Playwright::Events::Page::Response
      # Delay only response callback asynchronously to force out-of-order processing.
      Thread.new do
        sleep 0.1
        callback.call(*args)
      end
      true
    else
      super
    end
  end
end

Playwright::ChannelOwners::Page.prepend(ResponseCallbackDelayPatch)

RSpec.describe 'status_code race', sinatra: true do
  before do
    sinatra.get '/status' do
      'ok'
    end
  end

  around do |example|
    ResponseCallbackDelayPatch.enabled = true
    example.run
  ensure
    ResponseCallbackDelayPatch.enabled = false
  end

  it 'returns 200 immediately after visit even if response callback is delayed' do
    10.times do |i|
      visit "/status?i=#{i}"
      expect(page.status_code).to eq(200)
    end
  end
end
