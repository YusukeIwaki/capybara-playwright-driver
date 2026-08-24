require 'spec_helper'

RSpec.describe 'stale element handling' do
  before do
    visit 'about:blank'
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <div id="myid"></div>
      HTML
    end
  end

  def rerender_element
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const el = document.getElementById('myid');
        const newElement = el.cloneNode(true);
        newElement.textContent = 'New Element';
        el.replaceWith(newElement);
      })()
    JAVASCRIPT
  end

  def simulate_rerender_immediately_after_enabled_check
    # Hooks into the assert_element_not_stale method to simulate an HTML
    # element being replaced right after the staleness check, but before the block is called.
    original_method = Capybara::Playwright::Node.instance_method(:assert_element_not_stale)
    rerendered = false
    allow_any_instance_of(Capybara::Playwright::Node).to receive(:assert_element_not_stale) do |instance, &blk|
      original_method.bind(instance).call do
        unless rerendered
          rerender_element
          rerendered = true
        end
        blk.call
      end
    end
  end

  def install_button(event_name)
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <button id="myid">Old Element</button>
        <script>
          window.actionCount = 0;
          document.addEventListener('#{event_name}', function(event) {
            if (event.target.id === 'myid') window.actionCount += 1;
          });
        </script>
      HTML
    end
  end

  def replace_with_temporarily_disabled_button
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const oldButton = document.getElementById('myid');
        const newButton = oldButton.cloneNode(true);
        newButton.disabled = true;
        oldButton.replaceWith(newButton);
        setTimeout(() => { newButton.disabled = false }, 100);
      })()
    JAVASCRIPT
  end

  describe 'Element#inspect' do
    it 'works when the element is replaced between find and inspect' do
      el = find('#myid')

      rerender_element
      expect(el.inspect).to eq('Obsolete #<Capybara::Node::Element>')
    end

    it 'works when the element is replaced immediately after the staleness check' do
      el = find('#myid')

      simulate_rerender_immediately_after_enabled_check
      expect(el.inspect).to eq('Obsolete #<Capybara::Node::Element>')
    end
  end

  {
    click: 'click',
    right_click: 'contextmenu',
    double_click: 'dblclick',
  }.each do |action, event_name|
    it "retries #{action} and waits for the replacement to become actionable" do
      install_button(event_name)
      element = find('#myid')

      replace_with_temporarily_disabled_button
      element.public_send(action)

      expect(page.evaluate_script('window.actionCount')).to eq(1)
    end
  end

  it 'retries a centered offset click when the element is replaced during position calculation' do
    install_button('click')
    element = find('#myid')

    simulate_rerender_immediately_after_enabled_check
    element.click(x: 0, y: 0)

    expect(page.evaluate_script('window.actionCount')).to eq(1)
  end

  it 'retries hovering and preserves Playwright actionability waiting' do
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <style>
          #myid, #overlay { position: absolute; left: 0; top: 0; width: 100px; height: 40px; }
          #overlay { z-index: 1; }
        </style>
        <button id="myid">Old Element</button>
        <div id="overlay"></div>
        <script>
          window.hoverCount = 0;
          document.addEventListener('mouseover', function(event) {
            if (event.target.id === 'myid') window.hoverCount += 1;
          });
        </script>
      HTML
    end
    element = find('#myid')

    rerender_element
    page.execute_script("setTimeout(() => { document.getElementById('overlay').remove() }, 100)")
    element.hover

    expect(page.evaluate_script('window.hoverCount')).to eq(1)
  end

  it 'retries obscured checks after the element is replaced' do
    install_button('click')
    element = find('#myid')

    rerender_element

    expect(element.obscured?).to be false
  end

  it 'reloads both drag endpoints and releases the mouse before retrying' do
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <style>
          #source, #target { position: absolute; width: 50px; height: 50px; }
          #source { left: 0; top: 0; }
          #target { left: 200px; top: 0; }
        </style>
        <div id="source"></div>
        <div id="target"></div>
        <script>
          window.mouseupCount = 0;
          window.targetReplaced = false;
          document.addEventListener('mousedown', function(event) {
            if (event.target.id !== 'source' || window.targetReplaced) return;

            window.targetReplaced = true;
            const target = document.getElementById('target');
            target.replaceWith(target.cloneNode(true));
          });
          document.addEventListener('mouseup', function(event) {
            window.mouseupCount += 1;
            document.body.dataset.mouseupTarget = event.target.id;
          });
        </script>
      HTML
    end
    source = find('#source')
    target = find('#target')

    page.execute_script(<<~JAVASCRIPT)
      const source = document.getElementById('source');
      source.replaceWith(source.cloneNode(true));
    JAVASCRIPT
    source.drag_to(target)

    expect(page.evaluate_script('document.body.dataset.mouseupTarget')).to eq('target')
    expect(page.evaluate_script('window.mouseupCount')).to eq(2)
  end

  it 'retries filling when the selected input is replaced before typing' do
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <label for="field">Field</label>
        <input id="field">
        <script>
          const field = document.getElementById('field');
          field.addEventListener('focus', function() {
            if (window.replacementScheduled) return;

            window.replacementScheduled = true;
            queueMicrotask(function() {
              field.replaceWith(field.cloneNode(true));
            });
          });
        </script>
      HTML
    end

    fill_in 'Field', with: 'abc'

    expect(find('#field').value).to eq('abc')
  end

  it 'retries appending when the input is replaced after focusing' do
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <label for="field">Field</label>
        <input id="field" value="seed">
        <script>
          const field = document.getElementById('field');
          field.addEventListener('focus', function() {
            if (window.replacementScheduled) return;

            window.replacementScheduled = true;
            queueMicrotask(function() {
              const replacement = field.cloneNode(true);
              replacement.value = field.value;
              field.replaceWith(replacement);
            });
          });
        </script>
      HTML
    end

    fill_in 'Field', with: 'abc', fill_options: { clear: :none }

    expect(find('#field').value).to eq('seedabc')
  end

  it 'retries filling when the input is replaced after the first character' do
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <label for="field">Field</label>
        <input id="field">
        <script>
          const field = document.getElementById('field');
          field.addEventListener('input', function() {
            if (window.replacementScheduled) return;

            window.replacementScheduled = true;
            queueMicrotask(function() {
              const replacement = field.cloneNode(true);
              replacement.value = field.value;
              field.replaceWith(replacement);
            });
          });
        </script>
      HTML
    end

    fill_in 'Field', with: 'abc'

    expect(find('#field').value).to eq('abc')
  end
end
