module Burdock
  module Actions
    module Registry

      ActionMissingError = Class.new(StandardError)

      REGISTER = {}

      # @param [String] method_name
      # @param [#call] callable
      def self.put(method_name, callable)
        REGISTER[method_name.to_s] = callable
      end

      def self.get(method_name)
        maybe_action = REGISTER[method_name.to_s]

        if maybe_action
          yield maybe_action
        else
          error_message = "No action registered for method type `%s'" % [method_name]
          error = ActionMissingError.new(error_message)
          yield error
        end
      end

    end # RegisterAction
  end # Actions
end # Burdock
