module Capybara
  module Playwright
    class Browser
      def self.undefined_method(name)
        define_method(name) do |*args, **kwargs|
          puts "call #{name}(args=#{args}, kwargs=#{kwargs})"
          raise NotImplementedError.new("Capybara::Playwright::Browser##{name} is not implemented!")
        end
      end

      class NoSuchWindowError < StandardError ; end

      def initialize(playwright:, driver:, browser_type:, browser_options:, page_options:)
        @driver = driver

        browser_type = playwright.send(browser_type)
        @playwright_browser = browser_type.launch(**browser_options)
        @page_options = page_options
        @playwright_page = create_page(create_browser_context)
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

      private def create_browser_context
        @playwright_browser.new_context(**@page_options).tap do |browser_context|
          browser_context.on('page', ->(page) {
            unless @playwright_page
              @playwright_page = page
            end
          })
        end
      end

      private def create_page(browser_context)
        browser_context.new_page.tap do |page|
          page.on('close', -> {
            if @playwright_page
              @playwright_page = nil
            end
          })
          page.on('dialog', -> (dialog) {
            @dialog_event_handler.handle_dialog(dialog)
          })
          page.on('download', -> (download) {
            dest = File.join(Capybara.save_path, download.suggested_filename)
            # download.save_as blocks main thread until download completes.
            Thread.new(dest) { |_dest| download.save_as(_dest) }
          })
        end
      end

      def quit
        @playwright_browser.close
      end

      def current_url
        assert_page_alive

        @playwright_page.url
      end

      def visit(path)
        assert_page_alive

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
        assert_page_alive

        @playwright_page.evaluate('() => { location.reload(true) }')
      end

      def find_xpath(query, **options)
        assert_page_alive

        @playwright_page.query_selector_all("xpath=#{query}").map do |el|
          Node.new(@driver, @puppeteer_page, el)
        end
      end

      def find_css(query, **options)
        assert_page_alive

        @playwright_page.query_selector_all(query).map do |el|
          Node.new(@driver, @playwright_page, el)
        end
      end

      def html
        assert_page_alive

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

      def title
        assert_page_alive

        @playwright_page.title
      end

      def go_back
        assert_page_alive

        @playwright_page.go_back
      end

      def go_forward
        assert_page_alive

        @playwright_page.go_forward
      end

      def execute_script(script, *args)
        assert_page_alive

        @playwright_page.evaluate("function (arguments) { #{script} }", arg: unwrap_node(args))
        nil
      end

      def evaluate_script(script, *args)
        assert_page_alive

        result = @playwright_page.evaluate_handle("function (arguments) { return #{script} }", arg: unwrap_node(args))
        wrap_node(result)
      end

      undefined_method :evaluate_async_script

      def save_screenshot(path, **options)
        assert_page_alive

        @playwright_page.screenshot(path: path)
      end

      undefined_method :response_headers
      undefined_method :status_code
      undefined_method :send_keys
      undefined_method :switch_to_frame

      private def assert_page_alive
        if !@playwright_page || @playwright_page.closed?
          raise NoSuchWindowError
        end
      end

      private def pages
        @playwright_browser.contexts.flat_map(&:pages)
      end

      def window_handles
        pages.map(&:guid)
      end

      def current_window_handle
        @playwright_page&.guid
      end

      def open_new_window(kind = :tab)
        browser_context =
          if kind == :tab
            @playwright_page&.context || create_browser_context
          else
            create_browser_context
          end

        create_page(browser_context)
      end

      private def on_window(handle, &block)
        page = pages.find { |page| page.guid == handle }
        if page
          block.call(page)
        else
          raise NoSuchWindowError
        end
      end

      def switch_to_window(handle)
        if @playwright_page&.guid != handle
          on_window(handle) do |page|
            @playwright_page = page.tap(&:bring_to_front)
          end
        end
      end

      def close_window(handle)
        on_window(handle) do |page|
          page.close

          if @playwright_page&.guid == handle
            @playwright_page = nil
          end
        end
      end

      def window_size(handle)
        on_window(handle) do |page|
          page.evaluate('() => [window.innerWidth, window.innerHeight]')
        end
      end

      def resize_window_to(handle, width, height)
        on_window(handle) do |page|
          page.viewport_size = { width: width, height: height }
        end
      end

      def maximize_window(handle)
        puts "[WARNING] maximize_window is not supported in Playwright driver"
        # incomplete in Playwright
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/page.rb#L346
        on_window(handle) do |page|
          screen_size = page.evaluate('() => ({ width: window.screen.width, height: window.screen.height})')
          page.viewport_size = screen_size
        end
      end

      def fullscreen_window(handle)
        puts "[WARNING] fullscreen_window is not supported in Playwright driver"
        # incomplete in Playwright
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/page.rb#L341
        on_window(handle) do |page|
          page.evaluate('() => document.body.requestFullscreen()')
        end
      end

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
        assert_page_alive
        raise ArgumentError.new('block must be given') unless block

        block.call(@playwright_page)
      end
    end
  end
end
