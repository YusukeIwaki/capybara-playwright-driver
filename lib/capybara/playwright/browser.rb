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
        page.on('dialog', -> (dialog) {
          @dialog_event_handler.handle_dialog(dialog)
        })
        page.on('download', -> (download) {
          dest = File.join(Capybara.save_path, download.suggested_filename)
          # download.save_as blocks main thread until download completes.
          Thread.new(dest) { |_dest| download.save_as(_dest) }
        })

        @playwright_browser = browser
        @playwright_page = page
        @dialog_event_handler = DialogEventHandler.new
        @dialog_event_handler.default_handler = ->(dialog) {
          puts "[WARNING] Unexpected modal - \"#{dialog.message}\""
          if dialog.type == 'beforeunload'
            dialog.accept_async
          else
            dialog.dismiss
          end
        }
      end

      def quit
        @playwright_browser.close
      end

      def current_url
        @playwright_page.url
      end

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

      def go_back
        @playwright_page.go_back
      end

      def go_forward
        @playwright_page.go_forward
      end

      def execute_script(script, *args)
        @playwright_page.evaluate("function (arguments) { #{script} }", arg: unwrap_node(args))
        nil
      end

      def evaluate_script(script, *args)
        result = @playwright_page.evaluate_handle("function (arguments) { return #{script} }", arg: unwrap_node(args))
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

      class DialogAcceptor
        def initialize(dialog_type, options)
          @dialog_type = dialog_type
          @options = options
        end

        def handle(dialog)
          if @dialog_type == :prompt
            dialog.accept_async(promptText: @options[:with] || dialog.default_value)
          else
            dialog.accept_async
          end
        end
      end

      class DialogMessageMatcher
        def initialize(text_or_regex_or_nil)
          if [NilClass, Regexp, String].none? { |k| text_or_regex_or_nil.is_a?(k) }
            raise ArgumentError.new("invalid type: #{text_or_regex_or_nil.inspect}")
          end

          @filter = text_or_regex_or_nil
        end

        def matches?(message)
          case @filter
          when nil
            true
          when Regexp
            message =~ @filter
          when String
            message&.include?(@filter)
          end
        end
      end

      def accept_modal(dialog_type, **options, &block)
        timeout_sec = options[:wait]
        acceptor = DialogAcceptor.new(dialog_type, options)
        matcher = DialogMessageMatcher.new(options[:text])
        message_promise = Concurrent::Promises.resolvable_future
        handler = -> (dialog) {
          message = dialog.message
          if matcher.matches?(message)
            message_promise.fulfill(message)
            acceptor.handle(dialog)
          else
            message_promise.reject(Capybara::ModalNotFound.new("Dialog message=\"#{message}\" dowsn't match"))
            dialog.dismiss
          end
        }
        @dialog_event_handler.with_handler(handler) do
          block.call

          message = message_promise.value!(timeout_sec)
          if message_promise.fulfilled?
            message
          else
            # timed out
            raise Capybara::ModalNotFound
          end
        end
      end

      def dismiss_modal(dialog_type, **options, &block)
        timeout_sec = options[:wait]
        matcher = DialogMessageMatcher.new(options[:text])
        message_promise = Concurrent::Promises.resolvable_future
        handler = -> (dialog) {
          message = dialog.message
          if matcher.matches?(message)
            message_promise.fulfill(message)
          else
            message_promise.reject(Capybara::ModalNotFound.new("Dialog message=\"#{message}\" dowsn't match"))
          end
          dialog.dismiss
        }
        @dialog_event_handler.with_handler(handler) do
          block.call

          message = message_promise.value!(timeout_sec)
          if message_promise.fulfilled?
            message
          else
            # timed out
            raise Capybara::ModalNotFound
          end
        end
      end

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
        when ::Playwright::JSHandle
          arg.json_value
        else
          arg
        end
      end

      def with_playwright_page(&block)
        raise ArgumentError.new('block must be given') unless block

        block.call(@playwright_page)
      end
    end
  end
end
