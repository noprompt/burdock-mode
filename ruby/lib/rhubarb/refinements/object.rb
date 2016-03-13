module Rhubarb
  module Refinements
    module Object
      refine ::Object do
        # @return [Boolean]
        def float?
          ::Float === self
        end

        # @return [Boolean]
        def integer?
          ::Integer === self
        end

        # @return [Boolean]
        def number?
          ::Numeric === self
        end

        # @return [Boolean]
        def string?
          ::String === self
        end

        # @return [Boolean]
        def symbol?
          ::Symbol === self
        end
      end
    end # Object
  end # Refinements
end # Rhubarb
