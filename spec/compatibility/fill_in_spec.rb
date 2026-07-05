# frozen_string_literal: true

require 'date'
require 'spec_helper'

FILL_IN_FORM_HTML = <<~HTML
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

FILL_IN_KEYUP_TEXTAREA_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <label for="body">Body</label>
    <textarea id="body" name="body"></textarea>
    <div id="preview"></div>
    <script>
      body.addEventListener('keyup', function() {
        preview.textContent = body.value;
      });
    </script>
  </body>
  </html>
HTML

FILL_IN_EMOJI_TEXT = "a\u{1F600}cd\u{1F634} \u{1F6CC}\u{1F3FD}\u{1F1F5}\u{1F1F9} " \
                     "e\u{1F93E}\u{1F3FD}\u200D\u2640\uFE0Ff"

FILL_IN_HELPERS = Module.new do
  def track_form_date_events
    find(:css, '#form_date').execute_script <<~JS
      window.capybara_formDateFiredEvents = [];
      var fd = this;
      ['focus', 'input', 'change'].forEach(function(eventType) {
        fd.addEventListener(eventType, function() { window.capybara_formDateFiredEvents.push(eventType); });
      });
    JS
    find(:css, 'h1', text: 'Form').click
  end
end

RSpec.describe 'fill_in compatibility', sinatra: true do
  include FILL_IN_HELPERS

  before do
    sinatra.get('/') { FILL_IN_FORM_HTML }
    sinatra.get('/keyup') { FILL_IN_KEYUP_TEXTAREA_HTML }
  end

  it 'triggers keyup events' do
    visit '/keyup'

    fill_in 'Body', with: 'updated FAQ'

    expect(find(:fillable_field, 'Body').value).to eq('updated FAQ')
    expect(find(:css, '#preview')).to have_text('updated FAQ')
  end

  it 'replaces an existing value' do
    visit '/'
    fill_in('form_first_name', with: 'Harry', fill_options: { clear: :backspace })

    expect(find(:fillable_field, 'form_first_name').value).to eq('Harry')
  end

  it 'replaces an existing value even with caret position' do
    visit '/'
    find(:css, '#form_first_name').execute_script <<~JS
      this.focus();
      this.setSelectionRange(0, 0);
    JS

    fill_in('form_first_name', with: 'Harry', fill_options: { clear: :backspace })

    expect(find(:fillable_field, 'form_first_name').value).to eq('Harry')
  end

  it 'triggers onchange once' do
    visit '/'
    fill_in('with_change_event', with: 'some value', fill_options: { clear: :backspace })
    find(:css, '#with_focus_event').click

    expect(find(:css, '.change_event_triggered', match: :one, wait: 5)).to have_text 'some value'
  end

  it 'triggers change when clearing a field' do
    visit '/'
    fill_in('with_change_event', with: '', fill_options: { clear: :backspace })
    find(:css, '#with_focus_event').click

    expect(page).to have_selector(:css, '.change_event_triggered', match: :one, wait: 5, visible: :all)
  end

  it 'triggers input events per backspace' do
    visit '/'
    fill_in('with_change_event', with: '', fill_options: { clear: :backspace })
    find(:css, 'h1', text: 'Form').click

    expect(page).to have_css('p.input_event_triggered', count: 13, wait: 5, visible: :all)
  end

  it 'uses Capybara.default_set_options' do
    begin
      Capybara.default_set_options = { clear: :backspace }
      visit '/'
      fill_in('form_first_name', with: 'Thomas')

      expect(find(:fillable_field, 'form_first_name').value).to eq('Thomas')
    ensure
      Capybara.default_set_options = {}
    end
  end

  it 'appends with clear: :none' do
    visit '/'
    fill_in('form_first_name', with: 'Harry', fill_options: { clear: :none })

    expect(find(:fillable_field, 'form_first_name').value).to eq('JohnHarry')
  end

  it 'works with rapid fill and clear: :none' do
    long_string = (0...60).map { |i| ((i % 26) + 65).chr }.join
    visit '/'
    fill_in('form_first_name', with: long_string, fill_options: { clear: :none })

    expect(find(:fillable_field, 'form_first_name').value).to eq("John#{long_string}")
  end

  it 'passes clear key arrays through' do
    pending 'clear: Array is not supported by capybara-playwright-driver yet' if Capybara.current_driver == :playwright

    visit '/'
    fill_in('form_first_name',
            with: 'Harry',
            fill_options: { clear: [[:shift, 'abc'], :backspace] })

    expect(find(:fillable_field, 'form_first_name').value).to eq('JohnABHarry')
  end

  it 'generates standard events when changing date values' do
    visit '/'
    track_form_date_events

    fill_in('form_date', with: Date.today)

    expect(evaluate_script('window.capybara_formDateFiredEvents')).to eq %w[focus input change]
  end

  it 'does not generate input and change events if the value is not changed' do
    visit '/'
    track_form_date_events

    fill_in('form_date', with: Date.today)
    fill_in('form_date', with: Date.today)

    expect(evaluate_script('window.capybara_formDateFiredEvents')).to eq %w[focus input change]
  end

  it 'sends emojis' do
    visit '/'
    fill_in('form_first_name', with: FILL_IN_EMOJI_TEXT)

    expect(find(:fillable_field, 'form_first_name').value).to eq(FILL_IN_EMOJI_TEXT)
  end
end
