require "burdock/actions/registry"

module Burdock
  module Actions
    module RegisterAction

      # @param [Hash] message
      def self.call(message)
        params = message.fetch("params")
        file_path = params.fetch("file-path")
        action_name = params.fetch("action-name")
        constant_name = params.fetch("constant-name")

        Kernel.load(file_path)
        constant = Object.const_get(constant_name)
        Burdock::Actions::Registry.put(action_name, constant)

        {
          method: "burdock/noop",
          params: {},
        }
      end

      
    end # RegisterAction
  end # Actions
end # Burdock

Burdock::Actions::Registry.put("burdock/register-action", Burdock::Actions::RegisterAction)
