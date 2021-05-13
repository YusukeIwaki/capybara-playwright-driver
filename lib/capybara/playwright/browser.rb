module Capybara
  module Playwright
    class Browser
      extend Forwardable

      class NoSuchWindowError < StandardError ; end

      def initialize(playwright:, driver:, browser_type:, browser_options:, page_options:)
        @driver = driver

        browser_type = playwright.send(browser_type)
        @playwright_browser = browser_type.launch(**browser_options)
        @page_options = page_options
        @browser_windows = {}
        @current_window_handle = nil
        page = create_browser_context.new_page
        update_browser_window_with_page(page)
      end

      def quit
        @playwright_browser.close
      end

      private def create_browser_context
        @playwright_browser.new_context(**@page_options).tap do |browser_context|
          browser_context.on('page', ->(page) {
            update_browser_window_with_page(page)
          })
        end
      end

      private def update_browser_window_with_page(page)
        window_handle = page.guid
        @browser_windows[window_handle] ||= BrowserWindow.new(page)
        @current_window_handle ||= window_handle
      end

      private def find_browser_window(handle)
        browser_window = @browser_windows[handle]

        if !browser_window || browser_window.closed_or_closing?
          raise NoSuchWindowError
        end

        browser_window
      end

      private def current_browser_window
        raise NoSuchWindowError unless @current_window_handle

        find_browser_window(@current_window_handle)
      end

      def_delegator(:current_browser_window, :current_url)
      def_delegator(:current_browser_window, :visit)
      def_delegator(:current_browser_window, :refresh)
      def_delegator(:current_browser_window, :find_xpath)
      def_delegator(:current_browser_window, :find_css)
      def_delegator(:current_browser_window, :response_headers)
      def_delegator(:current_browser_window, :status_code)
      def_delegator(:current_browser_window, :title)
      def_delegator(:current_browser_window, :html)
      def_delegator(:current_browser_window, :go_back)
      def_delegator(:current_browser_window, :go_forward)
      def_delegator(:current_browser_window, :execute_script)
      def_delegator(:current_browser_window, :evaluate_script)
      def_delegator(:current_browser_window, :evaluate_async_script)
      def_delegator(:current_browser_window, :save_screenshot)
      def_delegator(:current_browser_window, :send_keys)
      def_delegator(:current_browser_window, :switch_to_frame)
      def_delegator(:current_browser_window, :accept_modal)
      def_delegator(:current_browser_window, :dismiss_modal)
      def_delegator(:current_browser_window, :with_playwright_page)

      def window_handles
        # clean up
        @browser_windows.reject! do |handle, browser_window|
          browser_window.closed_or_closing?
        end

        @browser_windows.keys
      end

      def current_window_handle
        @current_window_handle
      end

      def open_new_window(kind = :tab)
        browser_context =
          if @current_window_handle && kind == :tab
            find_browser_window(@current_window_handle).playwright_browser_context || create_browser_context
          else
            create_browser_context
          end

        create_page(browser_context)
      end

      def switch_to_window(handle)
        if @current_window_handle != handle
          find_browser_window(handle).bring_to_front
          @current_window_handle = handle
        end
      end

      def close_window(handle)
        if @current_window_handle == handle
          @current_window_handle = nil
        end
        find_browser_window(handle).close
      end

      def window_size(handle)
        find_browser_window(handle).window_size
      end

      def resize_window_to(handle, width, height)
        find_browser_window(handle).resize_window_to(width, height)
      end

      def maximize_window(handle)
        puts "[WARNING] maximize_window is not supported in Playwright driver"
        # incomplete in Playwright
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/page.rb#L346
        find_browser_window(handle).maximize_window
      end

      def fullscreen_window(handle)
        puts "[WARNING] fullscreen_window is not supported in Playwright driver"
        # incomplete in Playwright
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/page.rb#L341
        find_browser_window(handle).fullscreen_window
      end
    end
  end
end
