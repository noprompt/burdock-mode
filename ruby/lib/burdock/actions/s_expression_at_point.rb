require "burdock/actions/registry"
require "burdock/ast"
require "burdock/actions/expression_at_point/processor"

module Burdock
  module Actions
    module SExpressionAtPoint
      # @param [Hash] message
      # @return [Hash] message
      def self.call(message)
        params = message.fetch("params")
        point = params.fetch("point")
        source = params.fetch("source")

        processor = Burdock::Actions::ExpressionAtPoint::Processor.new(point)
        node = Burdock::AST.from_string(source)

        maybe_node = processor.process(node)

        if maybe_node
          expression = maybe_node.location.expression
          start_line = expression.first_line
          start_point = expression.begin_pos
          end_point = expression.end_pos
          end_line = expression.last_line

          s_expression = maybe_node.to_s

          {
            method: "burdock/source",
            params: {
              end_line: end_line,
              end_point: end_point,
              s_expression: s_expression,
              start_line: start_line,
              start_point: start_point
            }
          }
        else
          {
            method: "burdock/source",
            params: {
              end_line: nil,
              end_point: nil,
              source: nil,
              start_line: nil,
              start_point: nil
            }
          }
        end

      end

      # @return [Array]
      def self.required_parameters
        [
          "point",
          "source",
        ]
      end

    end # ExpressionAtPoint
  end
end

Burdock::Actions::Registry.put("burdock/s-expression-at-point", Burdock::Actions::SExpressionAtPoint)
