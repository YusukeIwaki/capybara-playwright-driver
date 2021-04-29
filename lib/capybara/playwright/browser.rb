module Capybara
  module Playwright
    class Browser
      def initialize(playwright:, driver:, browser_type:, browser_options:, page_options:)
        @driver = driver

        browser = playwright.send(browser_type).launch(**browser_options)

        page = browser.new_page(**page_options)

        @playwright_browser = browser
        @playwright_page = page
      end

      def quit
        @playwright_browser.close
      end

      def visit(path)
        url =
          if Capybara.app_host
            URI(Capybara.app_host).merge(path)
          else
            path
          end

        @playwright_page.goto(url)
      end

      def refresh
        @playwright_page.evaluate('() => { location.reload(true) }')
      end

      def find_xpath(query, **options)
        @playwright_page.wait_for_selector(
          "xpath=#{query}",
          state: :visible,
          timeout: Capybara.default_max_wait_time * 1000,
        )
        @playwright_page.query_selector_all("xpath=#{query}").map do |el|
          Node.new(@driver, @puppeteer_page, el)
        end
      end

      def find_css(query, **options)
        @playwright_page.wait_for_selector(
          query,
          state: :visible,
          timeout: Capybara.default_max_wait_time * 1000,
        )
        @playwright_page.query_selector_all(query).map do |el|
          Node.new(@driver, @playwright_page, el)
        end
      end

      def save_screenshot(path, **options)
        @playwright_page.screenshot(path: path)
      end
    end
  end
end
