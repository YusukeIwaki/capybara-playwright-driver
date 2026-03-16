# frozen_string_literal: true

require 'spec_helper'

# Ported from https://github.com/teamcapybara/capybara/blob/3.40.0/spec/shared_selenium_session.rb
RSpec.describe 'fill_in options', sinatra: true do
  before do
    # Ignore older versions without `#active_element` definition.
    skip if Gem::Version.new(Capybara::VERSION) < Gem::Version.new('3.36.0')

    sinatra.get '/' do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <h1>Form</h1>
          <form>
            <label for="form_first_name">
              First Name
              <input type="text" name="form[first_name]" value="John" id="form_first_name" tabindex="1"/>
            </label>
            <label for="form_date">
              Date
              <input type="date" name="form[date]" id="form_date"/>
            </label>
          </form>
          <input type="text" name="with_change_event" value="default value" id="with_change_event"/>
          <input type="text" name="with_focus_event" value="" id="with_focus_event"/>
          <script>
            document.getElementById('with_change_event').addEventListener('change', function() {
              var p = document.createElement('p');
              p.className = 'change_event_triggered';
              p.textContent = this.value;
              document.body.appendChild(p);
            });
            document.getElementById('with_change_event').addEventListener('input', function() {
              var p = document.createElement('p');
              p.className = 'input_event_triggered';
              p.textContent = this.value;
              document.body.appendChild(p);
            });
            document.getElementById('with_focus_event').addEventListener('focus', function() {
              var p = document.createElement('p');
              p.id = 'focus_event_triggered';
              p.textContent = 'Focus Event triggered';
              document.body.appendChild(p);
            });
          </script>
        </body>
        </html>
      HTML
    end
  end

  describe '#fill_in with { clear: :backspace } fill_option' do
    it 'should fill in a field, replacing an existing value' do
      visit '/'
      fill_in('form_first_name',
              with: 'Harry',
              fill_options: { clear: :backspace })
      expect(find(:fillable_field, 'form_first_name').value).to eq('Harry')
    end

    it 'should fill in a field, replacing an existing value, even with caret position' do
      visit '/'
      find(:css, '#form_first_name').execute_script <<~JS
        this.focus();
        this.setSelectionRange(0, 0);
      JS

      fill_in('form_first_name',
              with: 'Harry',
              fill_options: { clear: :backspace })
      expect(find(:fillable_field, 'form_first_name').value).to eq('Harry')
    end

    it 'should fill in if the option is set via global option' do
      begin
        Capybara.default_set_options = { clear: :backspace }
        visit '/'
        fill_in('form_first_name', with: 'Thomas')
        expect(find(:fillable_field, 'form_first_name').value).to eq('Thomas')
      ensure
        Capybara.default_set_options = {}
      end
    end

    it 'should only trigger onchange once' do
      visit '/'
      fill_in('with_change_event',
              with: 'some value',
              fill_options: { clear: :backspace })
      # click outside the field to trigger the change event
      find(:css, '#with_focus_event').click
      expect(find(:css, '.change_event_triggered', match: :one, wait: 5)).to have_text 'some value'
    end

    it 'should trigger change when clearing field' do
      visit '/'
      fill_in('with_change_event',
              with: '',
              fill_options: { clear: :backspace })
      # click outside the field to trigger the change event
      find(:css, '#with_focus_event').click
      expect(page).to have_selector(:css, '.change_event_triggered', match: :one, wait: 5)
    end

    it 'should trigger input event field_value.length times' do
      visit '/'
      fill_in('with_change_event',
              with: '',
              fill_options: { clear: :backspace })
      # click outside the field to trigger the change event
      find(:css, 'h1', text: 'Form').click
      # "default value" is 13 characters, so 13 input events should fire (one per backspace)
      expect(page).to have_css('p.input_event_triggered', count: 13, wait: 5)
    end
  end

  describe '#fill_in with { clear: :none } fill_option' do
    it 'should append to content in a field' do
      visit '/'
      fill_in('form_first_name',
              with: 'Harry',
              fill_options: { clear: :none })
      expect(find(:fillable_field, 'form_first_name').value).to eq('JohnHarry')
    end

    it 'works with rapid fill' do
      long_string = (0...60).map { |i| ((i % 26) + 65).chr }.join
      visit '/'
      fill_in('form_first_name', with: long_string, fill_options: { clear: :none })
      expect(find(:fillable_field, 'form_first_name').value).to eq("John#{long_string}")
    end
  end

  describe '#fill_in with Date' do
    before do
      visit '/'
      find(:css, '#form_date').execute_script <<~JS
        window.capybara_formDateFiredEvents = [];
        var fd = this;
        ['focus', 'input', 'change'].forEach(function(eventType) {
          fd.addEventListener(eventType, function() { window.capybara_formDateFiredEvents.push(eventType); });
        });
      JS
      # work around weird issue where it would create an extra focus event in some cases
      find(:css, 'h1', text: 'Form').click
    end

    it 'should generate standard events on changing value' do
      fill_in('form_date', with: Date.today)
      expect(evaluate_script('window.capybara_formDateFiredEvents')).to eq %w[focus input change]
    end

    it 'should not generate input and change events if the value is not changed' do
      fill_in('form_date', with: Date.today)
      fill_in('form_date', with: Date.today)
      # Chrome adds an extra focus for some reason - ok for now
      expect(evaluate_script('window.capybara_formDateFiredEvents')).to eq(%w[focus input change])
    end
  end

  describe '#fill_in with { clear: Array } fill_option' do
    it 'should pass the array through to the element', pending: true do
      # this is mainly for use with [[:control, 'a'], :backspace] - however since that is platform dependant
      # I'm testing with something less useful
      visit '/'
      fill_in('form_first_name',
              with: 'Harry',
              fill_options: { clear: [[:shift, 'abc'], :backspace] })
      expect(find(:fillable_field, 'form_first_name').value).to eq('JohnABHarry')
    end
  end

  describe '#fill_in with Emoji' do
    it 'sends emojis' do
      visit '/'
      fill_in('form_first_name', with: "a\u{1F600}cd\u{1F634} \u{1F6CC}\u{1F3FD}\u{1F1F5}\u{1F1F9} e\u{1F93E}\u{1F3FD}\u200D\u2640\uFE0Ff")
      expect(find(:fillable_field, 'form_first_name').value).to eq("a\u{1F600}cd\u{1F634} \u{1F6CC}\u{1F3FD}\u{1F1F5}\u{1F1F9} e\u{1F93E}\u{1F3FD}\u200D\u2640\uFE0Ff")
    end
  end

  describe '#send_keys' do
    it 'defaults to sending keys to the active_element' do
      visit '/'

      expect(page.active_element).to match_selector(:css, 'body')

      page.send_keys(:tab)

      expect(page.active_element).to match_selector(:css, '[tabindex="1"]')
    end
  end
end
