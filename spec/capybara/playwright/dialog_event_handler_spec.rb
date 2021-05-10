require 'spec_helper'

RSpec.describe Capybara::Playwright::DialogEventHandler do
  let(:handler) { Capybara::Playwright::DialogEventHandler.new }
  let(:mock_dialog) { double('dialog', message: 'dialog message') }

  it 'can add handler' do
    callback = double('callback')
    expect(callback).to receive(:called)
    handler.add_handler(-> (dialog) {
      callback.called(dialog)
    })
    handler.handle_dialog(mock_dialog)
  end

  it 'can remove handler' do
    callback = double('callback')
    expect(callback).not_to receive(:called)
    id = handler.add_handler(-> (dialog) {
      callback.called(dialog)
    })
    handler.remove_handler(id)
    handler.handle_dialog(mock_dialog)
  end

  it 'handles last added handler' do
    callback1 = double('callback1')
    callback2 = double('callback1')
    expect(callback1).not_to receive(:called)
    expect(callback2).to receive(:called)
    handler.add_handler(-> (dialog) {
      callback1.called(dialog)
    })
    handler.add_handler(-> (dialog) {
      callback2.called(dialog)
    })
    handler.handle_dialog(mock_dialog)
  end
end
