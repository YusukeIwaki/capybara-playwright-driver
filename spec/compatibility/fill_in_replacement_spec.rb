# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'fill_in replacement compatibility', sinatra: true, text_input: true do
  before do
    sinatra.get '/' do
      <<~HTML
        <!DOCTYPE html>
        <label for="field">Field</label>
        <input id="field" value="seed">
      HTML
    end
    visit '/'
  end

  it 'retries filling when the selected input is replaced before typing' do
    find('#field').execute_script(<<~JS)
      this.addEventListener('focus', function() {
        queueMicrotask(() => this.replaceWith(this.cloneNode(true)));
      }, { once: true });
    JS

    fill_in 'Field', with: 'abc'

    expect(find('#field').value).to eq('abc')
  end

  it 'retries appending when the input is replaced after focusing' do
    find('#field').execute_script(<<~JS)
      this.addEventListener('focus', function() {
        queueMicrotask(() => {
          const replacement = this.cloneNode(true);
          replacement.value = this.value;
          this.replaceWith(replacement);
        });
      }, { once: true });
    JS

    fill_in 'Field', with: 'abc', fill_options: { clear: :none }

    expect(find('#field').value).to eq('seedabc')
  end

  it 'retries send_keys when the input is replaced before the first key' do
    find('#field').execute_script(<<~JS)
      this.addEventListener('focus', function() {
        queueMicrotask(() => this.replaceWith(this.cloneNode(true)));
      }, { once: true });
    JS

    find('#field').send_keys('abc')

    expect(find('#field').value).to eq('seedabc')
  end

  it 'does not replay input when the element is replaced after typing starts' do
    find('#field').execute_script(<<~JS)
      this.addEventListener('input', function() {
        queueMicrotask(() => {
          const replacement = this.cloneNode(true);
          replacement.value = this.value;
          this.replaceWith(replacement);
        });
      }, { once: true });
    JS

    fill_in 'Field', with: 'abc'

    expect(find('#field').value).to eq('a')
  end

  it 'continues at the new focus when the original input is replaced while typing' do
    find('#field').execute_script(<<~JS)
      const nextField = document.createElement('input');
      nextField.id = 'next-field';
      this.after(nextField);
      this.addEventListener('input', function() {
        const replacement = this.cloneNode(true);
        replacement.value = this.value;
        this.replaceWith(replacement);
        nextField.focus();
      }, { once: true });
    JS

    fill_in 'Field', with: 'abc'

    expect([find('#field').value, find('#next-field').value]).to eq(%w[a bc])
  end
end
