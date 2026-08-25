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

  def drag_elements_replaced_before_action
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
          document.addEventListener('mouseup', function(event) {
            document.body.dataset.mouseupTarget = event.target.id;
          });
        </script>
      HTML
    end
    source = find('#source')
    target = find('#target')
    page.execute_script(<<~JAVASCRIPT)
      const source = document.getElementById('source');
      const target = document.getElementById('target');
      source.replaceWith(source.cloneNode(true));
      target.replaceWith(target.cloneNode(true));
    JAVASCRIPT

    [source, target]
  end

  def drag_elements_replaced_after_mouse_down
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
          window.mousedownCount = 0;
          window.mouseupCount = 0;
          window.targetReplaced = false;
          document.addEventListener('mousedown', function(event) {
            if (event.target.id !== 'source') return;

            window.mousedownCount += 1;
            if (window.targetReplaced) return;

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

    [source, target]
  end

  def perform_interrupted_drag(source, target)
    source.drag_to(target)
  rescue Capybara::Playwright::Node::DragInterruptedError
  end

  def attached_hidden_click_element
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <button class="item" id="original" style="display: none">Original</button>
      HTML
    end
    element = find('.item', visible: :all)
    page.execute_script(<<~JAVASCRIPT)
      const other = document.createElement('button');
      other.className = 'item';
      other.id = 'other';
      other.textContent = 'Other';
      document.getElementById('original').before(other);
    JAVASCRIPT

    element
  end

  def drag_with_attached_hidden_target
    page.driver.with_playwright_page do |page|
      page.content = <<~HTML
        <style>
          #source, .target { position: absolute; width: 50px; height: 50px; }
          #source { left: 0; top: 0; }
          #original { display: none; }
          #other { left: 200px; top: 0; }
        </style>
        <div id="source"></div>
        <div class="target" id="original"></div>
      HTML
    end
    source = find('#source')
    target = find('.target', visible: :all)
    page.execute_script(<<~JAVASCRIPT)
      const other = document.createElement('div');
      other.className = 'target';
      other.id = 'other';
      document.getElementById('original').before(other);
    JAVASCRIPT

    [source, target]
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

  it 'retries clicking and waits for the replacement to become actionable' do
    install_button('click')
    element = find('#myid')

    replace_with_temporarily_disabled_button
    element.click

    expect(page.evaluate_script('window.actionCount')).to eq(1)
  end

  it 'retries right-clicking and waits for the replacement to become actionable' do
    install_button('contextmenu')
    element = find('#myid')

    replace_with_temporarily_disabled_button
    element.right_click

    expect(page.evaluate_script('window.actionCount')).to eq(1)
  end

  it 'retries double-clicking and waits for the replacement to become actionable' do
    install_button('dblclick')
    element = find('#myid')

    replace_with_temporarily_disabled_button
    element.double_click

    expect(page.evaluate_script('window.actionCount')).to eq(1)
  end

  it 'retries a centered offset click when the element is replaced during position calculation' do
    install_button('click')
    element = find('#myid')

    simulate_rerender_immediately_after_enabled_check
    element.click(x: 0, y: 0)

    expect(page.evaluate_script('window.actionCount')).to eq(1)
  end

  it 'does not treat an attached click target without a bounding box as stale' do
    element = attached_hidden_click_element

    expect { element.click(x: 0, y: 0, offset: :center, wait: 0.5) }
      .to raise_error(Capybara::Playwright::Node::MissingBoundingBoxError)
  end

  it 'preserves the stale element error when click retries are disabled' do
    install_button('click')
    element = find('#myid')

    rerender_element

    expect { element.click(wait: false) }
      .to raise_error(Capybara::Playwright::Node::StaleReferenceError)
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

  it 'reloads both drag endpoints when they are replaced' do
    source, target = drag_elements_replaced_before_action
    source.drag_to(target)

    expect(page.evaluate_script('document.body.dataset.mouseupTarget')).to eq('target')
  end

  it 'does not treat an attached drag target without a bounding box as stale' do
    source, target = drag_with_attached_hidden_target

    expect { source.drag_to(target) }
      .to raise_error(Capybara::Playwright::Node::MissingBoundingBoxError)
  end

  it 'raises a non-retryable error when a drag target becomes stale after mouse down' do
    source, target = drag_elements_replaced_after_mouse_down

    expect { source.drag_to(target) }
      .to raise_error(Capybara::Playwright::Node::DragInterruptedError)
  end

  it 'does not repeat mouse down when a drag target becomes stale after input begins' do
    source, target = drag_elements_replaced_after_mouse_down

    expect { perform_interrupted_drag(source, target) }
      .to change { page.evaluate_script('window.mousedownCount') }.by(1)
  end

  it 'releases the mouse once when a drag target becomes stale after input begins' do
    source, target = drag_elements_replaced_after_mouse_down

    expect { perform_interrupted_drag(source, target) }
      .to change { page.evaluate_script('window.mouseupCount') }.by(1)
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
