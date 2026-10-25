# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Node#send_keys compatibility', sinatra: true, text_input: true do
  before do
    sinatra.get('/') { File.read(File.expand_path('../../fixtures/text_input.html', __dir__)) }
    sinatra.get('/frame') { '<iframe id="input-frame" src="/"></iframe>' }
    sinatra.get('/cross-origin-frame') { '<iframe id="input-frame" src="http://127.0.0.1:4567/frame-content"></iframe>' }
    sinatra.get('/frame-content') do
      headers 'X-Frame-Options' => 'ALLOWALL'
      File.read(File.expand_path('../../fixtures/text_input.html', __dir__))
    end
    visit '/'
  end

  it 'appends to an unfocused text input' do
    find('#first').send_keys('X')

    expect(find('#first').value).to eq('JohnX')
  end

  it 'appends to an unfocused textarea after its last line' do
    find('#area').send_keys('X')

    expect(find('#area').value).to eq("First line\nLast lineX")
  end

  it 'appends to an unfocused contenteditable' do
    find('#editor').send_keys('X')

    expect(find('#editor').text).to eq('HelloX')
  end

  it 'appends a new paragraph to an unfocused contenteditable' do
    find('#editor').send_keys("\nWorld")

    expect(find('#editor').evaluate_script('this.innerText')).to eq("Hello\nWorld")
  end

  it 'keeps the caret in a focused text input' do
    find('#first').execute_script('this.focus(); this.setSelectionRange(2, 2)')

    find('#first').send_keys('X')

    expect(find('#first').value).to eq('JoXhn')
  end

  it 'replaces the selection in a focused text input' do
    find('#first').execute_script('this.focus(); this.setSelectionRange(1, 3)')

    find('#first').send_keys('X')

    expect(find('#first').value).to eq('JXn')
  end

  it 'keeps the caret in a focused contenteditable' do
    find('#editor').execute_script('this.focus(); getSelection().collapse(this.firstChild, 2)')

    find('#editor').send_keys('X')

    expect(find('#editor').text).to eq('HeXllo')
  end

  it 'replaces the selection in a focused contenteditable' do
    find('#editor').execute_script(<<~JS)
      this.focus();
      getSelection().setBaseAndExtent(this.firstChild, 1, this.firstChild, 4);
    JS

    find('#editor').send_keys('X')

    expect(find('#editor').text).to eq('HXo')
  end

  it 'appends when a contenteditable is targeted again after losing focus' do
    find('#editor').execute_script('this.focus(); getSelection().collapse(this.firstChild, 2)')
    find('#outside').click

    find('#editor').send_keys('X')

    expect(find('#editor').text).to eq('HelloX')
  end

  it 'appends to a descendant of an unfocused editing host' do
    find('#paragraph').send_keys('X')

    expect(find('#article').evaluate_script('this.textContent')).to eq('KeepReplaceX')
  end

  it 'preserves a descendant selection when its editing host is focused' do
    find('#paragraph').execute_script(<<~JS)
      this.parentElement.focus();
      getSelection().collapse(this.firstChild, 2);
    JS

    find('#paragraph').send_keys('X')

    expect(find('#paragraph').text).to eq('ReXplace')
  end

  it 'continues typing in the field reached by a Tab key' do
    find('#first').send_keys(:tab, 'Z')

    expect([find('#first').value, find('#second').value]).to eq(%w[John Z])
  end

  it 'interprets a tab inside a string as a Tab key' do
    find('#first').send_keys("\tZ")

    expect([find('#first').value, find('#second').value]).to eq(%w[John Z])
  end

  it 'sends Delete to the chip focused by the preceding arrow key' do
    find('#chip-one').send_keys(:right, :delete)

    expect(all('[id^="chip-"]').map(&:text)).to eq(['One'])
  end

  it 'continues a key sequence in an autocomplete that takes focus' do
    find('#editor').execute_script(<<~JS)
      this.addEventListener('input', function() {
        if (!this.textContent.includes('@')) return;
        const search = document.getElementById('second');
        search.focus();
        search.setSelectionRange(0, 0);
      });
    JS

    find('#editor').send_keys('@', 'alice')

    expect(find('#second').value).to eq('aliceOther')
  end

  it 'appends after a mention autocomplete has taken focus between calls' do
    find('#editor').execute_script(<<~JS)
      this.addEventListener('input', function() {
        if (window.mentionOpened || !this.textContent.includes('@')) return;
        window.mentionOpened = true;
        document.getElementById('second').focus();
      });
    JS
    editor = find('#editor')
    editor.send_keys('@')

    editor.send_keys('alice')

    expect(editor.text).to eq('Hello@alice')
  end

  it 'honors explicit caret movement after a contenteditable loses focus' do
    editor = find('#editor')
    editor.send_keys(:end, '@')
    find('#outside').click

    editor.send_keys(:left, 'X')

    expect(editor.text).to eq('HelloX@')
  end

  it 'sends a key array without modifiers' do
    find('body').send_keys(['/'])

    expect(evaluate_script('window.keyEvents.map(event => event.key)')).to eq(['/'])
  end

  it 'preserves lowercase keys in a Control chord' do
    find('body').send_keys([:control, 'k'])

    expect(evaluate_script('window.keyEvents.find(event => event.key === "k").control')).to be(true)
  end

  it 'preserves special key names in a Shift chord' do
    find('#first').send_keys([:shift, :home])

    expect(find('#first').evaluate_script('this.value.slice(this.selectionStart, this.selectionEnd)')).to eq('John')
  end

  it 'releases array modifiers before the following text' do
    find('#first').send_keys([:shift, 'ab'], 'c')

    expect(find('#first').value).to eq('JohnABc')
  end

  it 'keeps top-level modifiers until a null key releases them' do
    find('#first').send_keys(:shift, 'ab', :null, 'c')

    expect(find('#first').value).to eq('JohnABc')
  end

  it 'appends to a contenteditable inside a frame' do
    visit '/frame'

    within_frame('input-frame') do
      find('#editor').send_keys("\nWorld")

      expect(find('#editor').evaluate_script('this.innerText')).to eq("Hello\nWorld")
    end
  end

  it 'returns keyboard focus to a frame with an already active editor' do
    visit '/frame'
    within_frame('input-frame') { find('#editor').send_keys('X') }
    find('body').execute_script('this.tabIndex = 0; this.focus()')

    within_frame('input-frame') do
      find('#editor').send_keys('Y')

      expect(find('#editor').text).to eq('HelloXY')
    end
  end

  it 'sends special keys to an editor inside a cross-origin frame' do
    visit '/cross-origin-frame'

    within_frame('input-frame') do
      find('#editor').send_keys("\nWorld")

      expect(find('#editor').evaluate_script('this.innerText')).to eq("Hello\nWorld")
    end
  end

  it 'sends special keys to an input inside a shadow root' do
    skip 'Capybara does not expose shadow roots' unless find('body').respond_to?(:shadow_root)
    find('body').execute_script(<<~JS)
      const host = document.createElement('div');
      host.id = 'shadow-host';
      this.append(host);
      host.attachShadow({ mode: 'open' }).innerHTML = '<input id="shadow-input" value="John">';
    JS
    input = find('#shadow-host').shadow_root.find('#shadow-input')

    input.send_keys(:left, 'X')

    expect(input.value).to eq('JohXn')
  end

  it 'preserves the selection in a focused shadow-root input' do
    skip 'Capybara does not expose shadow roots' unless find('body').respond_to?(:shadow_root)
    pending 'ChromeDriver moves a focused shadow-root input caret to the end' unless page.driver.is_a?(Capybara::Playwright::Driver)

    find('body').execute_script(<<~JS)
      const host = document.createElement('div');
      host.id = 'shadow-host';
      this.append(host);
      host.attachShadow({ mode: 'open' }).innerHTML = '<input id="shadow-input" value="John">';
    JS
    input = find('#shadow-host').shadow_root.find('#shadow-input')
    input.execute_script('this.focus(); this.setSelectionRange(1, 3)')

    input.send_keys('X')

    expect(input.value).to eq('JXn')
  end
end
