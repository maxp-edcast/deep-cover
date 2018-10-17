# frozen_string_literal: true

# This file is required by absolute path in the entry_points when doing clone mode.
# THERE MUST NOT BE ANY USE/REQUIRE OF DEPENDENCIES OF DeepCover HERE
# See deep-cover/core_gem/lib/deep_cover/setup/clone_mode_entry.rb for details

require_relative '../module_override'

# Adds a functionality to add callbacks before an `exec`

module DeepCover
  module ExecCallbacks
    class << self
      attr_reader :callbacks

      def before_exec(&block)
        self.active = true
        (@callbacks ||= []) << block
      end
    end

    def exec(*args)
      ExecCallbacks.callbacks.each(&:call)
      exec_without_deep_cover(*args)
    end

    extend ModuleOverride
    override ::Kernel, ::Kernel.singleton_class
    self.active = true
  end
end
