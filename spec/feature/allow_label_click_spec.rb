require 'spec_helper'
require 'timeout'

RSpec.describe 'allow_label_click with hidden inputs (ref: https://github.com/YusukeIwaki/capybara-playwright-driver/issues/120 )', sinatra: true do
  before do
    skip 'allow_label_click native patch is enabled only on Ruby >= 2.7' if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.7')
  end

  # USWDS-like styling: hides the actual input off-screen while keeping the label visible.
  # This is a common pattern used by design systems like USWDS, Bootstrap, etc.
  HIDDEN_INPUT_STYLE = <<~CSS
    .hidden-input {
      position: absolute;
      left: -999em;
      right: auto;
    }
    .visible-label {
      cursor: pointer;
      display: inline-block;
      padding-left: 2rem;
      position: relative;
    }
  CSS

  before do
    sinatra.get '/' do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <style>#{HIDDEN_INPUT_STYLE}</style>
        </head>
        <body>
          <fieldset>
            <legend>Radio buttons</legend>
            <div>
              <input class="hidden-input" type="radio" id="radio1" name="person" value="washington">
              <label class="visible-label" for="radio1">Booker T. Washington</label>
            </div>
            <div>
              <input class="hidden-input" type="radio" id="radio2" name="person" value="dubois">
              <label class="visible-label" for="radio2">W.E.B. Du Bois</label>
            </div>
          </fieldset>

          <fieldset>
            <legend>Checkboxes</legend>
            <div>
              <input class="hidden-input" type="checkbox" id="check1" name="agree" value="yes" checked>
              <label class="visible-label" for="check1">I agree</label>
            </div>
          </fieldset>

          <fieldset>
            <legend>Visible controls</legend>
            <div>
              <input type="radio" id="visible_radio" name="color" value="red">
              <label for="visible_radio">Red</label>
            </div>
          </fieldset>
        </body>
        </html>
      HTML
    end
  end

  # The max_wait_time is set to 5 seconds by the sinatra: true around hook in spec_helper.
  # Operations on hidden inputs should complete well under this threshold.
  # If the bug is present, they will take approximately default_max_wait_time seconds.
  let(:time_limit) { 1.5 }

  describe 'choose (radio button)' do
    it 'does not wait the full default_max_wait_time when allow_label_click: true' do
      visit '/'

      Timeout.timeout(time_limit) {
        choose 'Booker T. Washington', allow_label_click: true
      }

      expect(page).to have_checked_field('Booker T. Washington', visible: :all)
    end
  end

  describe 'check (checkbox)' do
    it 'does not wait the full default_max_wait_time when allow_label_click: true' do
      visit '/'

      # Uncheck first so we can test check
      uncheck 'I agree', allow_label_click: true

      Timeout.timeout(time_limit) {
        check 'I agree', allow_label_click: true
      }

      expect(page).to have_checked_field('I agree', visible: :all)
    end
  end

  describe 'uncheck (checkbox)' do
    it 'does not wait the full default_max_wait_time when allow_label_click: true' do
      visit '/'

      Timeout.timeout(time_limit) {
        uncheck 'I agree', allow_label_click: true
      }

      expect(page).to have_unchecked_field('I agree', visible: :all)
    end
  end

  describe 'click (for comparison)' do
    it 'clicks a visible label without delay' do
      visit '/'

      Timeout.timeout(time_limit) {
        find('label[for="visible_radio"]').click
      }

      expect(page).to have_checked_field('Red')
    end
  end
end
