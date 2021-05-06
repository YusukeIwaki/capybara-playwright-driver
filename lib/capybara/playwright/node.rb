module Capybara
  module Playwright
    module ElementClickOptionPatch
      def perform_click_action(keys, **options)
        # Expose `wait` value to the block given to perform_click_action.
        if options[:wait].is_a?(Numeric)
          options[:_playwright_wait] = options[:wait]
        end

        # Playwright has own auto-waiting feature.
        # So disable Capybara's retry logic.
        options[:wait] = 0
        super
      end
    end
    Capybara::Node::Element.prepend(ElementClickOptionPatch)

    class Node <  ::Capybara::Driver::Node
      # ref:
      #   selenium:   https://github.com/teamcapybara/capybara/blob/master/lib/capybara/selenium/node.rb
      #   cuprite:    https://github.com/rubycdp/cuprite/blob/master/lib/capybara/cuprite/node.rb
      #   apparition: https://github.com/twalpole/apparition/blob/master/lib/capybara/apparition/node.rb

      def initialize(driver, page, element)
        super(driver, element)
        @page = page
        @element = element
      end

      private def capybara_default_wait_time
        Capybara.default_max_wait_time * 1100 # with 10% buffer for allowing overhead.
      end

      protected

      attr_reader :element

      public

      class NotActionableError < StandardError ; end

      def all_text
        text = @element.text_content
        text.to_s.gsub(/[\u200b\u200e\u200f]/, '')
            .gsub(/[\ \n\f\t\v\u2028\u2029]+/, ' ')
            .gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
            .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
            .tr("\u00a0", ' ')
      end

      def visible_text
        return '' unless @element.visible?

        js = <<~JAVASCRIPT
          function(el){
            if (el.nodeName == 'TEXTAREA'){
              return el.textContent;
            } else if (el instanceof SVGElement) {
              return el.textContent;
            } else {
              return el.innerText;
            }
          }
        JAVASCRIPT
        text = @element.evaluate(js)
        text.to_s.gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
            .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
            .gsub(/\n+/, "\n")
            .tr("\u00a0", ' ')
      end

      def [](name)
        if name.to_s == 'checked'
          @element.get_property(name).json_value
        else
          @element[name]
        end
      end

      def value
        # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L31
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/node.rb#L728
        if tag_name == 'select' && @element.evaluate('el => el.multiple')
          @element.query_selector_all('option:checked').map do |option|
            option.evaluate('el => el.value')
          end
        else
          @element.evaluate('el => el.value')
        end
      end

      def style(styles)
        # Capybara provides default implementation.
        # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/node/element.rb#L92
        raise NotImplementedError
      end

      # @param value [String, Array] Array is only allowed if node has 'multiple' attribute
      # @param options [Hash] Driver specific options for how to set a value on a node
      def set(value, **options)
        settable_class =
          case tag_name
          when 'input'
            case @element['type']
            when 'radio'
              RadioButton
            when 'checkbox'
              Checkbox
            when 'file'
              raise NotImplementedError
            when 'date'
              raise NotImplementedError
            when 'time'
              raise NotImplementedError
            when 'datetime-local'
              raise NotImplementedError
            when 'color'
              raise NotImplementedError
            when 'range'
              raise NotImplementedError
            else
              TextInput
            end
          when 'textarea'
            TextInput
          else
            if @element.editable?
              TextInput
            else
              raise NotImplementedError
            end
          end

        settable_class.new(@element, capybara_default_wait_time).set(value, **options)
      rescue ::Playwright::TimeoutError => err
        raise NotActionableError.new(err)
      end

      class Settable
        def initialize(element, timeout)
          @element = element
          @timeout = timeout
        end
      end

      class RadioButton < Settable
        def set(**options)
          @element.check(timeout: @timeout)
        end
      end

      class Checkbox < Settable
        def set(value, **options)
          if value
            @element.check(timeout: @timeout)
          else
            @element.uncheck(timeout: @timeout)
          end
        end
      end

      class TextInput < Settable
        def set(value, **options)
          @element.fill(value, timeout: @timeout)
        rescue ::Playwright::TimeoutError
          raise if @element.editable?

          puts "[INFO] Node#set: element is not editable. #{@element}"
        end
      end

      def select_option
        select_element = parent_select_element
        if select_element.evaluate('el => el.multiple')
          selected_options = select_element.query_selector_all('option:checked')
          selected_options << @element
          select_element.select_option(element: selected_options, timeout: capybara_default_wait_time)
        else
          select_element.select_option(element: @element, timeout: capybara_default_wait_time)
        end
      end

      def unselect_option
        if parent_select_element.evaluate('el => el.multiple')
          @element.evaluate('el => el.selected = false')
        else
          raise Capybara::UnselectNotAllowed, 'Cannot unselect option from single select box.'
        end
      end

      private def parent_select_element
        @element.query_selector('xpath=ancestor::select')
      end

      def click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options, capybara_default_wait_time)
        @element.click(**click_options.as_params)
      end

      def right_click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options, capybara_default_wait_time)
        params = click_options.as_params
        params[:button] = 'right'
        @element.click(**params)
      end

      def double_click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options, capybara_default_wait_time)
        @element.dblclick(**click_options.as_params)
      end

      class ClickOptions
        def initialize(element, keys, options, default_timeout)
          @element = element
          @modifiers = keys.map do |key|
            MODIFIERS[key.to_sym] or raise ArgumentError.new("Unknown modifier key: #{key}")
          end
          if options[:x] && options[:y]
            @coords = {
              x: options[:x],
              y: options[:y],
            }
            @offset_center = options[:offset] == :center
          end
          @wait = options[:_playwright_wait]
          @delay = options[:delay]
          @default_timeout = default_timeout
        end

        def as_params
          {
            delay: delay_ms,
            modifiers: modifiers,
            position: position,
            timeout: timeout + delay_ms.to_i,
          }.compact
        end

        private def timeout
          if @wait
            if @wait <= 0
              raise NotSupportedByDriverError.new("wait should be > 0 (wait = 0 is not supported on this driver)")
            end

            @wait * 1000
          else
            @default_timeout
          end
        end

        private def delay_ms
          if @delay && @delay > 0
            @delay * 1000
          else
            nil
          end
        end

        MODIFIERS = {
          alt: 'Alt',
          control: 'Control',
          meta: 'Meta',
          shift: 'Shift',
        }.freeze

        private def modifiers
          if @modifiers.empty?
            nil
          else
            @modifiers
          end
        end

        private def position
          if @offset_center
            box = @element.bounding_box

            {
              x: @coords[:x] + box['width'] / 2,
              y: @coords[:y] + box['height'] / 2,
            }
          else
            @coords
          end
        end
      end

      def send_keys(*args)
        SendKeys.new(@element, args).execute
      end

      class SendKeys
        MODIFIERS = {
          alt: 'Alt',
          control: 'Control',
          meta: 'Meta',
          shift: 'Shift',
        }.freeze

        KEYS = {
          cancel: 'Cancel',
          help: 'Help',
          backspace: 'Backspace',
          tab: 'Tab',
          clear: 'Clear',
          return: 'Enter',
          enter: 'Enter',
          shift: 'Shift',
          control: 'Control',
          alt: 'Alt',
          pause: 'Pause',
          escape: 'Escape',
          space: 'Space',
          page_up: 'PageUp',
          page_down: 'PageDown',
          end: 'End',
          home: 'Home',
          left: 'ArrowLeft',
          up: 'ArrowUp',
          right: 'ArrowRight',
          down: 'ArrowDown',
          insert: 'Insert',
          delete: 'Delete',
          semicolon: 'Semicolon',
          equals: 'Equal',
          numpad0: 'Numpad0',
          numpad1: 'Numpad1',
          numpad2: 'Numpad2',
          numpad3: 'Numpad3',
          numpad4: 'Numpad4',
          numpad5: 'Numpad5',
          numpad6: 'Numpad6',
          numpad7: 'Numpad7',
          numpad8: 'Numpad8',
          numpad9: 'Numpad9',
          multiply: 'NumpadMultiply',
          add: 'NumpadAdd',
          separator: 'NumpadDecimal',
          subtract: 'NumpadSubtract',
          decimal: 'NumpadDecimal',
          divide: 'NumpadDivide',
          f1: 'F1',
          f2: 'F2',
          f3: 'F3',
          f4: 'F4',
          f5: 'F5',
          f6: 'F6',
          f7: 'F7',
          f8: 'F8',
          f9: 'F9',
          f10: 'F10',
          f11: 'F11',
          f12: 'F12',
          meta: 'Meta',
          command: 'Meta',
        }

        def initialize(element, keys)
          @element = element

          holding_keys = []
          @executables = keys.each_with_object([]) do |key, executables|
            if MODIFIERS[key]
              holding_keys << key
            else
              if holding_keys.empty?
                case key
                when String
                  executables << TypeText.new(key)
                when Symbol
                  executables << PressKey.new(
                    key: key_for(key),
                    modifiers: [],
                  )
                when Array
                  _key = key.last
                  code =
                    if _key.is_a?(String) && _key.length == 1
                      _key.upcase
                    elsif _key.is_a?(Symbol)
                      key_for(_key)
                    else
                      raise ArgumentError.new("invalid key: #{_key}. Symbol of 1-length String is expected.")
                    end
                  modifiers = key.first(key.size - 1).map { |k| modifier_for(k) }
                  executables << PressKey.new(
                    key: code,
                    modifiers: modifiers,
                  )
                end
              else
                modifiers = holding_keys.map { |k| modifier_for(k) }

                case key
                when String
                  key.each_char do |char|
                    executables << PressKey.new(
                      key: char.upcase,
                      modifiers: modifiers,
                    )
                  end
                when Symbol
                  executables << PressKey.new(
                    key: key_for(key),
                    modifiers: modifiers
                  )
                else
                  raise ArgumentError.new("#{key} cannot be handled with holding key #{holding_keys}")
                end
              end
            end
          end
        end

        private def modifier_for(modifier)
          MODIFIERS[modifier] or raise ArgumentError.new("invalid modifier specified: #{modifier}")
        end

        private def key_for(key)
          KEYS[key] or raise ArgumentError.new("invalid key specified: #{key}")
        end

        def execute
          @executables.each do |executable|
            executable.execute_for(@element)
          end
        end

        class PressKey
          def initialize(key:, modifiers:)
            puts "PressKey: key=#{key} modifiers: #{modifiers}"
            if modifiers.empty?
              @key = key
            else
              @key = (modifiers + [key]).join('+')
            end
          end

          def execute_for(element)
            element.press(@key)
          end
        end

        class TypeText
          def initialize(text)
            @text = text
          end

          def execute_for(element)
            element.type(@text)
          end
        end
      end

      def hover
        @element.hover(timeout: capybara_default_wait_time)
      end

      def drag_to(element, **options)
        raise NotImplementedError
      end

      def drop(*args)
        raise NotImplementedError
      end

      def scroll_by(x, y)
        raise NotImplementedError
      end

      def scroll_to(element, alignment, position = nil)
        raise NotImplementedError
      end

      def tag_name
        @tag_name ||= @element.evaluate('e => e.tagName.toLowerCase()')
      end

      def visible?
        if tag_name == 'option'
          # <option> tag for single selection is invisible if not selected in Playwright.
          # But Capybara expects it as visible.
          select_element = parent_select_element
          unless select_element.evaluate('el => el.multiple')
            return select_element.visible?
          end
        end

        @element.visible?
      end

      def obscured?
        # Playwright checks actionability automatically.
        # In most cases, checking obscured? manually is not required.
        raise NotSupportedByDriverError, 'Capybara::Driver::Node#obscured?'
      end

      def checked?
        @element.checked?
      rescue ::Playwright::Error => err
        raise unless err.message =~ /Not a checkbox or radio button/

        puts err.message
        false
      end

      def selected?
        @element.evaluate('el => el.selected')
      end

      def disabled?
        @element.disabled?
      end

      def readonly?
        !@element.editable?
      end

      def multiple?
        @element.evaluate('el => el.multiple')
      end

      def rect
        @element.bounding_box
      end

      def path
        # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L491
        js = <<~JAVASCRIPT
        (el) => {
          var xml = document;
          var xpath = '';
          var pos, tempitem2;
          if (el.getRootNode && el.getRootNode() instanceof ShadowRoot) {
            return "(: Shadow DOM element - no XPath :)";
          };
          while(el !== xml.documentElement) {
            pos = 0;
            tempitem2 = el;
            while(tempitem2) {
              if (tempitem2.nodeType === 1 && tempitem2.nodeName === el.nodeName) { // If it is ELEMENT_NODE of the same name
                pos += 1;
              }
              tempitem2 = tempitem2.previousSibling;
            }
            if (el.namespaceURI != xml.documentElement.namespaceURI) {
              xpath = "*[local-name()='"+el.nodeName+"' and namespace-uri()='"+(el.namespaceURI===null?'':el.namespaceURI)+"']["+pos+']'+'/'+xpath;
            } else {
              xpath = el.nodeName.toUpperCase()+"["+pos+"]/"+xpath;
            }
            el = el.parentNode;
          }
          xpath = '/'+xml.documentElement.nodeName.toUpperCase()+'/'+xpath;
          xpath = xpath.replace(/\\/$/, '');
          return xpath;
        }
        JAVASCRIPT
        @element.evaluate(js)
      end

      def trigger(event)
        @element.dispatch_event(event)
      end

      def inspect
        %(#<#{self.class} tag="#{tag_name}" path="#{path}">)
      end

      def ==(other)
        return false unless other.is_a?(Node)

        @element.evaluate('(self, other) => self == other', arg: other.element)
      end

      def find_xpath(query, **options)
        @element.query_selector_all("xpath=#{query}").map do |el|
          Node.new(@driver, @page, el)
        end
      end

      def find_css(query, **options)
        @element.query_selector_all(query).map do |el|
          Node.new(@driver, @page, el)
        end
      end
    end
  end
end
