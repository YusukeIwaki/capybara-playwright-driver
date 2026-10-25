[![Gem Version](https://badge.fury.io/rb/capybara-playwright-driver.svg)](https://badge.fury.io/rb/capybara-playwright-driver)

# 🎭 Playwright driver for Capybara

Make it easy to introduce Playwright into your Rails application.

```ruby
gem 'capybara-playwright-driver'
```

**NOTE**: If you want to use Playwright-native features (such as auto-waiting, various type of locators, ...), [consider using playwright-ruby-client directly](https://playwright-ruby-client.vercel.app/docs/article/guides/rails_integration_with_null_driver).

## Examples

```ruby
require 'capybara-playwright-driver'

# setup
Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(app, browser_type: :firefox, headless: false)
end
Capybara.default_max_wait_time = 15
Capybara.default_driver = :playwright
Capybara.save_path = 'tmp/capybara'

# run
Capybara.app_host = 'https://github.com'
visit '/'
find('button[aria-label^="Search or jump to"]').click
search_field = find('input[aria-label="Search or jump to"]')
search_field.fill_in(with: 'Capybara')

## [REMARK] We can use Playwright-native selector and action, instead of Capybara DSL.
# search_field.send_keys(:enter)
page.driver.with_playwright_page do |page|
  page.get_by_label('Search or jump to', exact: true).press('Enter')
end

all('[data-testid="results-list"] h3').each do |li|
  #puts "#{li.all('a').first.text} by Capybara"
  puts "#{li.with_playwright_element_handle { |handle| handle.text_content }} by Playwright"
end
```

Refer the [documentation](https://playwright-ruby-client.vercel.app/docs/article/guides/rails_integration) for more detailed configuration.

## Selenium compatibility

`visible?` and selector filters such as `visible: true` do not account for ancestor overflow clipping. An element
completely clipped by an ancestor with `overflow: hidden` can still be considered visible by this driver, while
Selenium considers it hidden. This can change the results of queries such as `all('.item', visible: true)` when
migrating Selenium tests.

Playwright's native visibility methods (`ElementHandle#visible?` and `Locator#visible?` in playwright-ruby-client)
also consider these clipped elements visible. If a test needs to count items actually displayed inside a clipped
container, check their geometry relative to the container explicitly. See
[#174](https://github.com/YusukeIwaki/capybara-playwright-driver/issues/174) for the driver comparison and discussion.

Visible text for ordinary HTML elements follows the browser's
[`innerText` behavior](https://html.spec.whatwg.org/multipage/dom.html#the-innertext-idl-attribute). This preserves
meaningful blank lines, but paragraph and rich-text-editor boundaries can differ from Selenium's WebDriver text
algorithm. When exact whitespace is not part of an assertion, use Capybara's `normalize_ws: true` option:

```ruby
expect(message).to have_text('Hello Regards', normalize_ws: true)
```

Element `send_keys` follows WebDriver's focus and selection rules: an unfocused text input, textarea, or
`contenteditable` starts at the end of its content; an already focused element keeps its caret or selection.
The element is prepared once per call. Subsequent keys follow focus changes made by the application, including Tab
navigation and autocomplete controls. For example, a new call can return to an editor after its autocomplete takes focus:

```ruby
editor.send_keys('@') # The page moves focus to an autocomplete control.
editor.send_keys('alice') # Focus the editor again and append at its end.
```

`set`, `fill_in`, and `send_keys` use the same keyboard sequence handling, including Enter for newlines and Tab for
tab characters. Replacement selects the target content before typing, including inherited `contenteditable` children.
`clear: :none` preserves an existing selection when the input already has focus; `clear: :backspace` and key arrays
send their clearing keys before the replacement text. Elements replaced during focus or selection can be retried
before typing starts. Once typing begins, the sequence is not replayed when the original element is replaced.

The compatibility specs record two intentional differences from Capybara Selenium: setting an empty string clears
`contenteditable` content, and a focused input inside a shadow root keeps its selection instead of moving to the end.

Text entry uses Playwright's typing behavior for every character regardless of the value length. Playwright sends
`keydown`, `keypress`/`input`, and `keyup` for characters on a US keyboard, but sends only
`input` for other characters, including Japanese text. This follows
[Playwright's documented keyboard behavior](https://playwright.dev/docs/api/class-keyboard#keyboard-type). Typing very
large values is slower than Playwright's native `fill`, which does not send per-character keyboard events. When input
speed matters more than those events, consider using `fill` directly:

```ruby
page.driver.with_playwright_page { |playwright_page| playwright_page.get_by_label('Body').fill(large_value) }
```

## Development

Prepare to run tests:

```bash
bundle install
export PLAYWRIGHT_CLI_VERSION=$(bundle exec ruby -e 'require "playwright"; puts Playwright::COMPATIBLE_PLAYWRIGHT_VERSION.strip')
npm install playwright@${PLAYWRIGHT_CLI_VERSION}
./node_modules/.bin/playwright install --with-deps
```

Now, run tests: note that they are run in a virtual framebuffer (Xvfb).

```bash
PLAYWRIGHT_CLI_EXECUTABLE_PATH=./node_modules/.bin/playwright xvfb-run bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capybara::Playwright project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/YusukeIwaki/capybara-playwright-driver/blob/main/CODE_OF_CONDUCT.md).
