module Capybara
  module Playwright
    class Browser
      def self.undefined_method(name)
        define_method(name) do |*args, **kwargs|
          puts "call #{name}(args=#{args}, kwargs=#{kwargs})"
          raise NotImplementedError.new("Capybara::Playwright::Browser##{name} is not implemented!")
        end
      end

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

      undefined_method :current_url

      def visit(path)
        url =
          if Capybara.app_host
            URI(Capybara.app_host).merge(path)
          elsif Capybara.default_host
            URI(Capybara.default_host).merge(path)
          else
            path
          end

        @playwright_page.goto(url)
      end

      def refresh
        @playwright_page.evaluate('() => { location.reload(true) }')
      end

      def find_xpath(query, **options)
        @playwright_page.query_selector_all("xpath=#{query}").map do |el|
          Node.new(@driver, @puppeteer_page, el)
        end
      end

      def find_css(query, **options)
        @playwright_page.query_selector_all(query).map do |el|
          Node.new(@driver, @playwright_page, el)
        end
      end

      def html
        js = <<~JAVASCRIPT
        () => {
          let html = '';
          if (document.doctype) html += new XMLSerializer().serializeToString(document.doctype);
          if (document.documentElement) html += document.documentElement.outerHTML;
          return html;
        }
        JAVASCRIPT
        @playwright_page.evaluate(js)
      end

      undefined_method :go_back
      undefined_method :go_forward

      def execute_script(script, *args)
        @playwright_page.evaluate("function (arguments) { #{script} }", arg: unwrap_node(args))
        nil
      end

      def evaluate_script(script, *args)
        result = @playwright_page.evaluate("function (arguments) { return #{script} }", arg: unwrap_node(args))
        wrap_node(result)
      end

      undefined_method :evaluate_async_script

      def save_screenshot(path, **options)
        @playwright_page.screenshot(path: path)
      end

      undefined_method :response_headers
      undefined_method :status_code
      undefined_method :send_keys
      undefined_method :switch_to_frame
      undefined_method :current_window_handle
      undefined_method :window_size
      undefined_method :resize_window_to
      undefined_method :maximize_window
      undefined_method :fullscreen_window
      undefined_method :close_window
      undefined_method :window_handles
      undefined_method :open_new_window
      undefined_method :switch_to_window
      undefined_method :no_such_window_error
      undefined_method :accept_modal
      undefined_method :dismiss_modal

      private def unwrap_node(args)
        args.map do |arg|
          if arg.is_a?(Node)
            arg.send(:element)
          else
            arg
          end
        end
      end

      private def wrap_node(arg)
        case arg
        when Array
          arg.map do |item|
            wrap_node(item)
          end
        when Hash
          arg.map do |key, value|
            [key, wrap_node(value)]
          end.to_h
        when ::Playwright::ElementHandle
          Node.new(@driver, @puppeteer_page, arg)
        else
          arg
        end
      end
    end
  end
end
