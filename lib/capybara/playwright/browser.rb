require_relative './tmpdir_owner'

module Capybara
  module Playwright
    # Responsibility of this class is:
    # - Handling Capybara::Driver commands.
    # - Managing Playwright browser contexts and pages.
    #
    # Note that this class doesn't manage Playwright::Browser.
    # We should not use Playwright::Browser#close in this class.
    class Browser
      include TmpdirOwner
      extend Forwardable

      class NoSuchWindowError < StandardError ; end

      def initialize(driver:, playwright_browser:, page_options:, record_video: false)
        @driver = driver
        @playwright_browser = playwright_browser
        @page_options = page_options
        if record_video
          @page_options[:record_video_dir] ||= tmpdir
        end
        @playwright_page = create_page(create_browser_context)
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
        end
      end

      def clear_browser_contexts
        @playwright_browser.contexts.each(&:close)
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

        @playwright_page.capybara_current_frame.goto(url)
      end

      def refresh
        assert_page_alive

        @playwright_page.capybara_current_frame.evaluate('() => { location.reload(true) }')
      end

      def find_xpath(query, **options)
        assert_page_alive

        @playwright_page.capybara_current_frame.query_selector_all("xpath=#{query}").map do |el|
          Node.new(@driver, @playwright_page, el)
        end
      end

      def find_css(query, **options)
        assert_page_alive

        @playwright_page.capybara_current_frame.query_selector_all(query).map do |el|
          Node.new(@driver, @playwright_page, el)
        end
      end

      def response_headers
        assert_page_alive

        @playwright_page.capybara_response_headers
      end

      def status_code
        assert_page_alive

        @playwright_page.capybara_status_code
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
        @playwright_page.capybara_current_frame.evaluate(js)
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

        @playwright_page.capybara_current_frame.evaluate("function (arguments) { #{script} }", arg: unwrap_node(args))
        nil
      end

      def evaluate_script(script, *args)
        assert_page_alive

        result = @playwright_page.capybara_current_frame.evaluate_handle("function (arguments) { return #{script} }", arg: unwrap_node(args))
        wrap_node(result)
      end

      def evaluate_async_script(script, *args)
        assert_page_alive

        js = <<~JAVASCRIPT
        function(_arguments){
          let args = Array.prototype.slice.call(_arguments);
          return new Promise((resolve, reject) => {
            args.push(resolve);
            (function(){ #{script} }).apply(this, args);
          });
        }
        JAVASCRIPT
        result = @playwright_page.capybara_current_frame.evaluate_handle(js, arg: unwrap_node(args))
        wrap_node(result)
      end

      # Not used by Capybara::Session.
      # Intended to be directly called by user.
      def video_path
        return nil if !@playwright_page || @playwright_page.closed?

        @playwright_page.video&.path
      end

      # Not used by Capybara::Session.
      # Intended to be directly called by user.
      def raw_screenshot(**options)
        return nil if !@playwright_page || @playwright_page.closed?

        @playwright_page.screenshot(**options)
      end

      def save_screenshot(path, **options)
        assert_page_alive

        @playwright_page.screenshot(path: path)
      end

      def send_keys(*args)
        Node::SendKeys.new(@playwright_page.keyboard, args).execute
      end

      def switch_to_frame(frame)
        assert_page_alive

        case frame
        when :top
          @playwright_page.capybara_reset_frames
        when :parent
          @playwright_page.capybara_pop_frame
        else
          playwright_frame = frame.native.content_frame
          raise ArgumentError.new("Not a frame element: #{frame}") unless playwright_frame
          @playwright_page.capybara_push_frame(playwright_frame)
        end
      end

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

      def accept_modal(dialog_type, **options, &block)
        assert_page_alive

        @playwright_page.capybara_accept_modal(dialog_type, **options, &block)
      end

      def dismiss_modal(dialog_type, **options, &block)
        assert_page_alive

        @playwright_page.capybara_dismiss_modal(dialog_type, **options, &block)
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
          Node.new(@driver, @playwright_page, arg)
        when ::Playwright::JSHandle
          obj_type, is_array = arg.evaluate('obj => [typeof obj, Array.isArray(obj)]')
          if obj_type == 'object'
            if is_array
              arg.properties.map do |_, value|
                wrap_node(value)
              end
            else
              arg.properties.map do |key, value|
                [key, wrap_node(value)]
              end.to_h
            end
          else
            arg.json_value
          end
        else
          arg
        end
      end

      def with_playwright_page(&block)
        assert_page_alive

        block.call(@playwright_page)
      end
    end
  end
end
