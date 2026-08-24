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
        const newElement = document.createElement('div');
        newElement.id = 'myid';
        newElement.textContent = 'New Element';
        document.getElementById('myid').replaceWith(newElement);
      })()
    JAVASCRIPT
  end

  def simulate_rerender_immediately_after_enabled_check
    # Hooks into the assert_element_not_stale method to simulate an HTML
    # element being replaced right after the staleness check, but before the block is called.
    original_method = Capybara::Playwright::Node.instance_method(:assert_element_not_stale)
    allow_any_instance_of(Capybara::Playwright::Node).to receive(:assert_element_not_stale) do |instance, &blk|
      original_method.bind(instance).call do
        rerender_element
        blk.call
      end
    end
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
