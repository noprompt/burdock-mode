require "ast"

module Rhubarb
  module Refinements
    module AST
      refine ::AST::Node do
        # @param [Integer] line_number
        # @return [Boolean]
        def contains_line?(line_number)
          if expression?
            line_a = self.location.first_line
            line_b = self.location.last_line
            line_number.between?(line_a, line_b)
          else
            false
          end
        end

        # @param [Integer] point
        # @return [Boolean]
        def contains_point?(point)
          if expression?
            expression = self.location.expression
            point_a = expression.begin_pos
            point_b = expression.end_pos

            point.between?(point_a, point_b)
          else
            false
          end
        end

        # @return [Boolean]
        def expression?
          !!self.location.expression
        end

        # @param [Integer] line_number
        # @return [Boolean]
        def on_line?(line_number)
          if expression?
            line_a = self.location.first_line
            line_b = self.location.last_line
            line_number == line_a && line_number == line_b
          else
            false
          end
        end

      end
    end # AST
  end # Refinements
end # Rhubarb
