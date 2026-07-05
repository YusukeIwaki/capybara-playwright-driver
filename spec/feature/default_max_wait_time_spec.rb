require 'spec_helper'

RSpec.describe 'default_max_wait_time coercion', sinatra: true do
  before do
    sinatra.get('/checkbox') do
      <<~HTML
      <body>
        <input type="checkbox" id="agree" />
      </body>
      HTML
    end
  end

  # Mimics an ActiveSupport::Duration (e.g. `20.seconds`): it is not a Float,
  # multiplication keeps it a non-Float, but it responds to #to_f. Without the
  # coercion this value reaches playwright-ruby-client and raises
  # "expected float, got string".
  let(:duration_like) do
    Class.new do
      def initialize(value)
        @value = value
      end

      def *(other)
        self.class.new(@value * other)
      end

      def to_f
        @value.to_f
      end

      def to_s
        @value.to_s
      end
    end.new(5)
  end

  around do |example|
    original_wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = duration_like
    example.run
    Capybara.default_max_wait_time = original_wait_time
  end

  it 'coerces a non-Float default_max_wait_time before passing it to Playwright', driver: :playwright do
    captured_timeout = nil
    allow_any_instance_of(Playwright::ElementHandle).to receive(:check).and_wrap_original do |method, **options|
      captured_timeout = options[:timeout]
      method.call(**options)
    end

    visit '/checkbox'
    check('agree')

    expect(captured_timeout).to be_a(Float)
    expect(find('#agree')).to be_checked
  end
end
