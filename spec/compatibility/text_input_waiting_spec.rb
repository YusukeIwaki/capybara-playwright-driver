# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Text input waiting compatibility', sinatra: true, text_input: true do
  # Playwright press waits for the navigation commit; Selenium can return before it.
  # Disable Capybara's assertion retries for Playwright so they cannot hide a missing wait.
  let(:navigation_wait_time) { page.driver.is_a?(Capybara::Playwright::Driver) ? 0 : Capybara.default_max_wait_time }

  before do
    sinatra.get('/') do
      <<~HTML
        <!DOCTYPE html>
        <div id="editor" contenteditable="true" role="textbox">seed</div>
        <form action="/submitted">
          <input id="field" name="field">
          <input id="next-field" name="next-field">
          <button type="submit">Submit</button>
        </form>
      HTML
    end
    sinatra.get('/submitted') do
      sleep 0.5
      'submitted'
    end
    visit '/'
  end

  it 'preserves the driver enabled-state waiting when setting a contenteditable' do
    editor = find('#editor')
    editor.execute_script(<<~JS)
      this.style.display = 'none';
      this.addEventListener('input', () => {
        window.disabledAtInput = this.getAttribute('aria-disabled');
      }, { once: true });
      setTimeout(() => {
        this.setAttribute('aria-disabled', 'true');
        this.style.display = 'block';
      }, 300);
      setTimeout(() => this.setAttribute('aria-disabled', 'false'), 1000);
    JS

    editor.set('abc')

    # Playwright's fill waits for ARIA disabled state; WebDriver does not.
    expected = page.driver.is_a?(Capybara::Playwright::Driver) ? 'false' : 'true'
    expect(evaluate_script('window.disabledAtInput')).to eq(expected)
  end

  it 'preserves the driver readonly-state waiting when setting a contenteditable' do
    editor = find('#editor')
    editor.execute_script(<<~JS)
      this.style.display = 'none';
      this.addEventListener('input', () => {
        window.readonlyAtInput = this.getAttribute('aria-readonly');
      }, { once: true });
      setTimeout(() => {
        this.setAttribute('aria-readonly', 'true');
        this.style.display = 'block';
      }, 300);
      setTimeout(() => this.setAttribute('aria-readonly', 'false'), 1000);
    JS

    editor.set('abc')

    # Playwright's fill waits for ARIA readonly state; WebDriver does not.
    expected = page.driver.is_a?(Capybara::Playwright::Driver) ? 'false' : 'true'
    expect(evaluate_script('window.readonlyAtInput')).to eq(expected)
  end

  it 'waits for a text input to become visible before setting its value' do
    field = find('#field')
    field.execute_script(<<~JS)
      this.style.display = 'none';
      setTimeout(() => this.style.display = 'block', 300);
    JS

    field.set('abc')

    expect(field.value).to eq('abc')
  end

  it 'reloads a contenteditable replaced while waiting for visibility' do
    editor = find('#editor')
    editor.execute_script(<<~JS)
      this.style.display = 'none';
      setTimeout(() => {
        const replacement = this.cloneNode(true);
        replacement.style.display = 'block';
        this.replaceWith(replacement);
      }, 300);
    JS

    editor.set('abc')

    expect(find('#editor').text).to eq('abc')
  end

  it 'waits for navigation caused by an Enter key' do
    find('#field').send_keys(:enter)

    expect(page).to have_current_path('/submitted', ignore_query: true, wait: navigation_wait_time)
  end

  it 'waits for navigation caused by Enter after typing text' do
    find('#field').send_keys('abc', :enter)

    expect(page).to have_current_path('/submitted', ignore_query: true, wait: navigation_wait_time)
  end

  it 'waits for navigation from the next input focused by Tab' do
    find('#field').send_keys(:tab, :enter)

    expect(page).to have_current_path('/submitted', ignore_query: true, wait: navigation_wait_time)
  end

  it 'reports a navigation timeout after typing as a non-retryable interruption' do
    skip 'Selenium send_keys does not use the Playwright action timeout' unless page.driver.is_a?(Capybara::Playwright::Driver)
    field = find('#field')

    Capybara.using_wait_time(0.2) do
      expect { field.set("abc\n") }.to raise_error(Capybara::Playwright::Node::InputInterruptedError, /Timeout/)
    end
  end
end
