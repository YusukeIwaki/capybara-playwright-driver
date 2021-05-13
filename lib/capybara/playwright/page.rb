module Capybara
  module Playwright
    module PageExtension
      def initialize(*args, **kwargs)
        super
        capybara_initialize
      end

      private def capybara_initialize
        on('dialog', -> (dialog) {
          dialog_event_handler.handle_dialog(dialog)
        })
        on('download', -> (download) {
          dest = File.join(Capybara.save_path, download.suggested_filename)
          # download.save_as blocks main thread until download completes.
          Thread.new(dest) { |_dest| download.save_as(_dest) }
        })
      end

      private def dialog_event_handler
        @dialog_event_handler ||= DialogEventHandler.new.tap do |h|
          h.default_handler = method(:on_unexpected_modal)
        end
      end

      private def on_unexpected_modal(dialog)
        puts "[WARNING] Unexpected modal - \"#{dialog.message}\""
        if dialog.type == 'beforeunload'
          dialog.accept_async
        else
          dialog.dismiss
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
        dialog_event_handler.with_handler(handler) do
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
        dialog_event_handler.with_handler(handler) do
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
    end
    ::Playwright::Page.prepend(PageExtension)
  end
end
