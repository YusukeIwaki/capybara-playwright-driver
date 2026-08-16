# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Capybara::Playwright::BrowserRunner::PlaywrightCreate do # rubocop:disable Metrics/BlockLength
  let(:options) { {} }
  let(:playwright_cli_error) { '' }
  let(:status) { instance_double(Process::Status, success?: true) }

  before do
    allow(Open3).to receive(:capture3).and_return([playwright_cli_output, playwright_cli_error, status])
  end

  context 'when version matches' do
    let(:playwright_cli_output) { 'Version 1.62.1' }

    before { stub_const('Playwright::COMPATIBLE_PLAYWRIGHT_VERSION', '1.62.1') }

    it 'does not raise an error' do
      expect { described_class.new(options) }.not_to raise_error
    end
  end

  context 'when version does not match' do
    let(:playwright_cli_output) { 'Version 1.61.0' }

    before { stub_const('Playwright::COMPATIBLE_PLAYWRIGHT_VERSION', '1.62.1') }

    it 'raises an error' do
      expect do
        described_class.new(options)
      end.to raise_error(RuntimeError, /Playwright version mismatch/)
    end
  end

  context 'when a prerelease has the same numeric version' do
    let(:playwright_cli_output) { 'Version 1.62.1-next-20260811' }

    before { stub_const('Playwright::COMPATIBLE_PLAYWRIGHT_VERSION', '1.62.1') }

    it 'raises an error' do
      expect do
        described_class.new(options)
      end.to raise_error(RuntimeError, /Playwright version mismatch/)
    end
  end

  context 'when playwright CLI output is unexpected' do
    let(:playwright_cli_output) { 'Unexpected output' }

    it 'raises an error' do
      expect do
        described_class.new(options)
      end.to raise_error(RuntimeError, /Could not extract Playwright version/)
    end
  end

  context 'when the playwright CLI command fails' do
    let(:playwright_cli_output) { '' }
    let(:playwright_cli_error) { 'playwright: command not found' }
    let(:status) { instance_double(Process::Status, success?: false, exitstatus: 127) }

    it 'raises an error with the command failure' do
      expect do
        described_class.new(options)
      end.to raise_error(RuntimeError, /Could not get Playwright version \(exit 127\)/)
    end
  end
end
