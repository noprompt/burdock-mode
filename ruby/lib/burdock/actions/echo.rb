require "burdock/actions/registry"

module Burdock
  module Actions
    class Echo
      # @param [Hash] message
      def self.call(message)
        message
      end
    end # Echo
  end # Actions
end # Burdock

Burdock::Actions::Registry.put("burdock/echo", Burdock::Actions::Echo)
