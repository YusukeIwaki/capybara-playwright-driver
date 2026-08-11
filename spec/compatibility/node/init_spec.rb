# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Capybara::Playwright::BrowserRunner::PlaywrightCreate do # rubocop:disable Metrics/BlockLength
  let(:options) { {} }
  context 'when version matches' do
    before do
      allow_any_instance_of(described_class).to receive(:get_version_from_playwright_cli).and_return('Version 1.62.1')
      stub_const('Playwright::COMPATIBLE_PLAYWRIGHT_VERSION', '1.62.1')
    end

    it 'does not raise an error' do
      expect { described_class.new(options) }.not_to raise_error
    end
  end

  context 'when version does not match' do
    before do
      allow_any_instance_of(described_class).to receive(:get_version_from_playwright_cli).and_return('Version 1.61.0')
      stub_const('Playwright::COMPATIBLE_PLAYWRIGHT_VERSION', '1.62.1')
    end

    it 'raises an error' do
      expect do
        described_class.new(options)
      end.to raise_error(RuntimeError, /Playwright version mismatch/)
    end
  end

  context 'when playwright CLI output is unexpected' do
    before do
      allow_any_instance_of(described_class).to receive(:get_version_from_playwright_cli).and_return('Unexpected output')
    end

    it 'raises an error' do
      expect do
        described_class.new(options)
      end.to raise_error(RuntimeError, /Could not extract Playwright version/) # rubocop:disable Lint/Syntax
    end
  end
end
