module Capybara
  module Playwright
    module DriverExtension
      # Register screenshot save process.
      # The callback is called just before page is closed.
      # (just before #reset_session!)
      #
      # The **binary** (String) of the page screenshot is called back into the given block
      def on_save_raw_screenshot_before_reset(&block)
        @callback_on_save_screenshot = block
      end

      private def callback_on_save_screenshot?
        !!@callback_on_save_screenshot
      end

      private def callback_on_save_screenshot(raw_screenshot)
        @callback_on_save_screenshot&.call(raw_screenshot)
      end

      # Register screenrecord save process.
      # The callback is called just after page is closed.
      # (just after #reset_session!)
      #
      # The video path (String) is called back into the given block
      def on_save_screenrecord(&block)
        @callback_on_save_screenrecord = block
      end

      private def callback_on_save_screenrecord?
        !!@callback_on_save_screenrecord
      end

      private def callback_on_save_screenrecord(video_path)
        @callback_on_save_screenrecord&.call(video_path)
      end

      def with_playwright_page(&block)
        raise ArgumentError.new('block must be given') unless block

        @browser&.with_playwright_page(&block)
      end
    end
  end
end
