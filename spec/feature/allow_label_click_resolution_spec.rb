# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe 'allow_label_click control resolution', sinatra: true do
  before do
    skip 'allow_label_click native patch requires Ruby >= 2.7' if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.7')

    hidden_input_style = '<style>.hidden-input { position: absolute; left: -999em; }</style>'

    sinatra.get('/colliding-labels') do
      <<~HTML
        #{hidden_input_style}
        <input class="hidden-input" id="owner" type="radio" name="person">
        <label for="owner">Owner</label>
        <input class="hidden-input" id="owners-guest" type="radio" name="person">
        <label for="owners-guest">Owner's guest</label>

        <input class="hidden-input" id="guest-radio" type="radio">
        <label for="guest-radio">Guests</label>
        <input hidden id="guest-count" type="number">
        <label for="guest-count">Guests</label>

        <input class="hidden-input" id="updates" type="checkbox">
        <label for="updates">Updates</label>
        <input hidden id="updates-count" type="number">
        <label for="updates-count">Updates</label>

        <input class="hidden-input" id="reminders" type="checkbox" checked>
        <label for="reminders">Reminders</label>
        <input hidden id="reminders-count" type="number">
        <label for="reminders-count">Reminders</label>
      HTML
    end

    sinatra.get('/partial-label') do
      <<~HTML
        #{hidden_input_style}
        <input class="hidden-input" id="owners-guest" type="radio">
        <label for="owners-guest">Owner's guest</label>
      HTML
    end

    sinatra.get('/scoped-labels') do
      <<~HTML
        #{hidden_input_style}
        <fieldset id="outside">
          <input class="hidden-input" id="outside-radio" type="radio" name="person">
          <label for="outside-radio">Owner</label>
          <input class="hidden-input" id="outside-updates" type="checkbox">
          <label for="outside-updates">Updates</label>
          <input class="hidden-input" id="outside-reminders" type="checkbox" checked>
          <label for="outside-reminders">Reminders</label>
        </fieldset>
        <fieldset id="inside">
          <input class="hidden-input" id="inside-radio" type="radio" name="person">
          <label for="inside-radio">Owner's guest</label>
          <input class="hidden-input" id="inside-updates" type="checkbox">
          <label for="inside-updates">Updates</label>
          <input class="hidden-input" id="inside-reminders" type="checkbox" checked>
          <label for="inside-reminders">Reminders</label>
        </fieldset>
      HTML
    end

    sinatra.get('/frame-labels') do
      <<~HTML
        #{hidden_input_style}
        <input class="hidden-input" id="outside-radio" type="radio">
        <label for="outside-radio">Guests</label>
        <iframe id="controls" src="/frame-controls"></iframe>
      HTML
    end

    sinatra.get('/frame-controls') do
      <<~HTML
        #{hidden_input_style}
        <input class="hidden-input" id="frame-radio" type="radio">
        <label for="frame-radio">Guests</label>
      HTML
    end

    sinatra.get('/ambiguous-labels') do
      <<~HTML
        #{hidden_input_style}
        <input class="hidden-input" id="first-radio" type="radio" name="person">
        <label for="first-radio">Guests</label>
        <input class="hidden-input" id="second-radio" type="radio" name="person">
        <label for="second-radio">Guests</label>
      HTML
    end

    sinatra.get('/disabled-checkbox') do
      <<~HTML
        #{hidden_input_style}
        <input class="hidden-input" id="disabled-updates" type="checkbox" checked disabled>
        <label for="disabled-updates">Updates</label>
      HTML
    end

    sinatra.get('/delayed-radio') do
      <<~HTML
        <div id="fields"></div>
        <script>
          setTimeout(() => {
            document.getElementById('fields').innerHTML =
              '<input id="late-radio" type="radio"><label for="late-radio">Guests</label>';
          }, 300);
        </script>
      HTML
    end
  end

  around do |example|
    previous_label_click = Capybara.automatic_label_click
    begin
      Capybara.automatic_label_click = true
      example.run
    ensure
      Capybara.automatic_label_click = previous_label_click
    end
  end

  # The Sinatra hook sets default_max_wait_time to 5 seconds; label clicks should finish sooner.
  let(:time_limit) { 1.5 }

  it 'chooses the exact radio label without waiting on a partial match' do
    visit '/colliding-labels'

    Timeout.timeout(time_limit) { choose 'Owner' }

    expect(page).to have_checked_field('owner', visible: :all)
  end

  it 'chooses a radio without waiting on a number field with the same label' do
    visit '/colliding-labels'

    Timeout.timeout(time_limit) { choose 'Guests' }

    expect(page).to have_checked_field('guest-radio', visible: :all)
  end

  it 'checks a checkbox without waiting on a number field with the same label' do
    visit '/colliding-labels'

    Timeout.timeout(time_limit) { check 'Updates' }

    expect(page).to have_checked_field('updates', visible: :all)
  end

  it 'unchecks a checkbox without waiting on a number field with the same label' do
    visit '/colliding-labels'

    Timeout.timeout(time_limit) { uncheck 'Reminders' }

    expect(page).to have_unchecked_field('reminders', visible: :all)
  end

  it 'chooses a partial radio label when no exact match exists' do
    visit '/partial-label'

    Timeout.timeout(time_limit) { choose 'Owner' }

    expect(page).to have_checked_field('owners-guest', visible: :all)
  end

  it 'chooses a radio within scope even when an exact label exists outside it' do
    visit '/scoped-labels'

    Timeout.timeout(time_limit) do
      within('#inside') { choose 'Owner' }
    end

    expect(page).to have_checked_field('inside-radio', visible: :all)
  end

  it 'checks only the checkbox within scope when labels are identical' do
    visit '/scoped-labels'

    Timeout.timeout(time_limit) do
      within('#inside') { check 'Updates' }
    end

    expect(all(:checkbox, 'Updates', checked: true, visible: :all).map { |checkbox| checkbox[:id] }).to eq(['inside-updates'])
  end

  it 'unchecks only the checkbox within scope when labels are identical' do
    visit '/scoped-labels'

    Timeout.timeout(time_limit) do
      within('#inside') { uncheck 'Reminders' }
    end

    expect(all(:checkbox, 'Reminders', checked: true, visible: :all).map { |checkbox| checkbox[:id] }).to eq(['outside-reminders'])
  end

  it 'reloads a replaced scope after the initial lookup finds a stale element' do
    visit '/scoped-labels'

    within('#inside') do
      page.execute_script('const fieldset = document.getElementById("inside"); fieldset.replaceWith(fieldset.cloneNode(true))')

      check 'Updates'
    end

    expect(page).to have_checked_field('inside-updates', visible: :all)
  end

  it 'chooses the radio in the current frame when the outer page has the same label' do
    visit '/frame-labels'

    within_frame('controls') do
      Timeout.timeout(time_limit) { choose 'Guests' }

      expect(page).to have_checked_field('frame-radio', visible: :all)
    end
  end

  it 'raises for ambiguous radio labels' do
    visit '/ambiguous-labels'

    Capybara.using_wait_time(0) do
      expect { choose 'Guests' }.to raise_error(Capybara::Ambiguous)
    end
  end

  it 'rejects a disabled checkbox even when it is already checked' do
    visit '/disabled-checkbox'

    Capybara.using_wait_time(0) do
      expect { check 'Updates' }.to raise_error(Capybara::ElementNotFound)
    end
  end

  it 'waits for a radio to appear after the initial lookup finds nothing' do
    visit '/delayed-radio'

    choose 'Guests'

    expect(page).to have_checked_field('late-radio')
  end
end
