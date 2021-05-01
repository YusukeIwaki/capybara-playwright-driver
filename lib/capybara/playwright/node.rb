module Capybara
  module Playwright
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

      protected

      attr_reader :element

      public

      def all_text
        text = @element.text_content
        text.to_s.gsub(/[\u200b\u200e\u200f]/, '')
            .gsub(/[\ \n\f\t\v\u2028\u2029]+/, ' ')
            .gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
            .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
            .tr("\u00a0", ' ')
      end

      def visible_text
        return '' unless visible?

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
        @element[name]
      end

      def value
        # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L31
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/node.rb#L728
        js = <<~JAVASCRIPT
        el => {
          if (el.tagName == "select" && el.multiple)
            return Array.from(el.querySelectorAll("option:checked"), e => e.value)
          else
            return el.value
        }
        JAVASCRIPT
        @element.evaluate(js)
      end

      def style(styles)
        raise NotImplementedError
      end

      # @param value [String, Array] Array is only allowed if node has 'multiple' attribute
      # @param options [Hash] Driver specific options for how to set a value on a node
      def set(value, **options)
        @element.fill(value, timeout: Capybara.default_max_wait_time * 1000)
      rescue ::Playwright::TimeoutError
        raise if @element.editable?

        puts "[INFO] Node#set: element is not editable. #{@element}"
      end

      def select_option
        raise NotImplementedError
      end

      def unselect_option
        raise NotImplementedError
      end

      def click(keys = [], **options)
        if visible?
          @element.click
        else
          super
        end
      end

      def right_click(keys = [], **options)
        raise NotImplementedError
      end

      def double_click(keys = [], **options)
        if visible?
          @element.dblclick
        else
          super
        end
      end

      def send_keys(*args)
        raise NotImplementedError
      end

      def hover
        @element.hover
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
        @element.evaluate('e => e.tagName.toLowerCase()')
      end

      def visible?
        @element.visible?
      end

      def obscured?
        raise NotImplementedError
      end

      def checked?
        @element.checked?
      end

      def selected?
        raise NotImplementedError
      end

      def disabled?
        @element.disabled?
      end

      def readonly?
        raise NotImplementedError
      end

      def multiple?
        raise NotImplementedError
      end

      def rect
        raise NotSupportedByDriverError, 'Capybara::Driver::Node#rect'
      end

      def path
        raise NotSupportedByDriverError, 'Capybara::Driver::Node#path'
      end

      def trigger(event)
        raise NotSupportedByDriverError, 'Capybara::Driver::Node#trigger'
      end

      def inspect
        %(#<#{self.class} tag="#{tag_name}" path="#{path}">)
      rescue NotSupportedByDriverError
        %(#<#{self.class} tag="#{tag_name}">)
      end

      def ==(other)
        return false unless other.is_a?(Node)

        @element.evaluate('(other) => this == other', arg: other.element)
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
