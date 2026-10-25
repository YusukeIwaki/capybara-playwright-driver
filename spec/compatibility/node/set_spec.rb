# frozen_string_literal: true

require 'spec_helper'

SET_TAB_KEY_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <label for="tag">Tag</label>
    <input id="tag" name="tag">
    <label for="amount">Amount</label>
    <input id="amount" name="amount" type="number">
    <div id="status">waiting</div>
    <script>
      [tag, amount].forEach(function(input) {
        input.addEventListener('keydown', function(event) {
          if (event.key === 'Tab') {
            event.preventDefault();
            document.getElementById('status').textContent = 'tabbed:' + input.value;
            alert('tab was pressed');
          }
        });
      });
    </script>
  </body>
  </html>
HTML

RSpec.describe 'Node#set compatibility', sinatra: true, text_input: true do
  before do
    sinatra.get('/tab-key') { SET_TAB_KEY_HTML }
    sinatra.get('/') { File.read(File.expand_path('../../fixtures/text_input.html', __dir__)) }
  end

  it 'presses Tab instead of inserting a literal tab' do
    visit '/tab-key'

    accept_alert('tab was pressed', wait: 0.5) do
      find('#tag').set("bad tag\t")
    end

    expect(find('#status').text).to eq('tabbed:bad tag')
  end

  it 'presses Tab when setting a number input' do
    visit '/tab-key'

    accept_alert('tab was pressed', wait: 0.5) do
      find('#amount').set("12\t")
    end

    expect(find('#status').text).to eq('tabbed:12')
  end

  it 'replaces contenteditable text using keyboard events' do
    visit '/'
    find('#editor').set('abc')

    expect(evaluate_script('window.keyEvents.map(event => event.key)')).to eq(%w[a b c])
  end

  it 'replaces only the selected contenteditable descendant' do
    visit '/'
    find('#paragraph').set('Updated')

    expect(find('#article').evaluate_script('this.textContent')).to eq('KeepUpdated')
  end

  it 'clears a contenteditable descendant without changing its siblings' do
    pending 'Capybara Selenium sends no keys for an empty contenteditable value' unless page.driver.is_a?(Capybara::Playwright::Driver)

    visit '/'
    find('#paragraph').set('')

    expect(find('#article').text).to eq('Keep')
  end

  it 'sends an internal newline as Enter in a contenteditable' do
    visit '/'
    find('#editor').execute_script(<<~JS)
      this.addEventListener('keydown', function(event) {
        if (event.key === 'Enter') event.preventDefault();
      });
    JS

    find('#editor').set("A\nB")

    expect(find('#editor').evaluate_script('this.innerText')).to eq('AB')
  end

  it 'sends a leading newline as Enter in a contenteditable' do
    visit '/'
    find('#editor').execute_script(<<~JS)
      this.addEventListener('keydown', function(event) {
        if (event.key === 'Enter') event.preventDefault();
      });
    JS

    find('#editor').set("\nA")

    expect(find('#editor').text).to eq('A')
  end

  it 'sends a trailing newline as Enter in a contenteditable' do
    visit '/'
    find('#editor').set("A\n")

    expect(evaluate_script('window.keyEvents.map(event => event.key)')).to eq(%w[A Enter])
  end

  it 'continues after a Tab in a contenteditable at the new focus' do
    visit '/'
    find('#editor').set("A\tZ")

    expect(find('#article').evaluate_script('this.textContent')).to eq('ZKeepReplace')
  end

  it 'continues after a Tab in a text input at the new focus' do
    visit '/'
    find('#first').set("A\tZ")

    expect([find('#first').value, find('#second').value]).to eq(%w[A Z])
  end

  it 'sends a leading Tab to the field being replaced' do
    visit '/'
    find('#first').set("\tZ")

    expect([find('#first').value, find('#second').value]).to eq(['John', 'Z'])
  end

  it 'normalizes CRLF in replacement textarea text' do
    visit '/'
    find('#area').set("A\r\nB\r\n")

    expect(find('#area').value).to eq("A\nB\n")
  end

  it 'keeps a focused input caret with clear: :none' do
    visit '/'
    find('#first').execute_script('this.focus(); this.setSelectionRange(2, 2)')

    find('#first').set('X', clear: :none)

    expect(find('#first').value).to eq('JoXhn')
  end

  it 'keeps a focused textarea caret with clear: :none' do
    visit '/'
    find('#area').execute_script('this.focus(); this.setSelectionRange(2, 2)')

    find('#area').set('X', clear: :none)

    expect(find('#area').value).to eq("FiXrst line\nLast line")
  end

  it 'preserves a focused selection with clear: :none' do
    visit '/'
    find('#first').execute_script('this.focus(); this.setSelectionRange(1, 3)')

    find('#first').set('X', clear: :none)

    expect(find('#first').value).to eq('JXn')
  end

  it 'does not send End to an application when appending' do
    visit '/'
    find('#first').set('X', clear: :none)

    expect(evaluate_script('window.keyEvents.some(event => event.key === "End")')).to be(false)
  end
end
