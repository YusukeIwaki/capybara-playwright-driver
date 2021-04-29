# 🎭 Playwright driver for Capybara

```ruby
gem 'capybara-playwright-driver'
```

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
fill_in('q', with: 'Capybara')
find('a[data-item-type="global_search"]').click
all('.repo-list-item').each do |li|
  puts li.all('a').first.text
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capybara::Playwright project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/capybara-playwright/blob/master/CODE_OF_CONDUCT.md).
