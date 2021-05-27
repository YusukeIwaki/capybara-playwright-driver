[![Gem Version](https://badge.fury.io/rb/capybara-playwright-driver.svg)](https://badge.fury.io/rb/capybara-playwright-driver)

# 🎭 Playwright driver for Capybara

#### [Docs](https://playwright-ruby-client.vercel.app/docs/article/guides/rails_integration)

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

## [REMARK] We can use Playwright-native selector and action, instead of Capybara DSL.
# find('a[data-item-type="global_search"]').click
page.driver.with_playwright_page do |page|
  page.click('a[data-item-type="global_search"]')
end

all('.repo-list-item').each do |li|
  #puts "#{li.all('a').first.text} by Capybara"
  puts "#{li.with_playwright_element_handle { |handle| handle.query_selector('a').text_content }} by Playwright"
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capybara::Playwright project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/capybara-playwright/blob/master/CODE_OF_CONDUCT.md).
