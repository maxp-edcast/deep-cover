# frozen_string_literal: true

# This file is required by absolute path in the entry_points when doing clone mode.
# THERE MUST NOT BE ANY USE/REQUIRE OF DEPENDENCIES OF DeepCover HERE
# See deep-cover/core_gem/lib/deep_cover/setup/clone_mode_entry.rb for details

module DeepCover
  module Tools
    module AfterTests
      def self.after_tests
        use_at_exit = true
        if defined?(::Minitest)
          use_at_exit = false
          ::Minitest.after_run { yield }
        end
        if defined?(::Rspec)
          use_at_exit = false
          ::RSpec.configure do |config|
            config.after(:suite) { yield }
          end
        end
        if use_at_exit
          at_exit { yield }
        end
      end

      def after_tests
        AfterTests.after_tests { yield }
      end
    end
  end
end
