module Capybara
  module Playwright
    module CallerDetection
      def called_for_finding?
        caller_locations.each do |loc|
          if loc.absolute_path.include?('lib/capybara/node/matchers.rb')
            return false
          elsif loc.absolute_path.include?('lib/capybara/session.rb')
            if %w[fill_in find].include?(loc.label)
              return true
            end
          else
            next
          end
        end

        false
      end
    end
  end
end
