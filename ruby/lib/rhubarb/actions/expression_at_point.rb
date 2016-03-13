require "unparser"

require_relative "../ast"
require_relative "expression_at_point/processor"

module Rhubarb
  module Actions
    module ExpressionAtPoint
      # @param [Hash] message
      # @return [Hash] message
      def self.call(message)
        params = message.fetch("params")
        point = params.fetch("point")
        source = params.fetch("source")

        processor = Rhubarb::Actions::ExpressionAtPoint::Processor.new(point)
        node = Rhubarb::AST.from_string(source)

        maybe_node = processor.process(node)

        if maybe_node
          expression = maybe_node.location.expression
          start_point = expression.begin_pos
          end_point = expression.end_pos

          source = Unparser.unparse(maybe_node)

          {
            method: "rhubarb_source",
            params: {
              end_point: end_point,
              source: source,
              start_point: start_point
            }
          }
        else
          {
            method: "rhubarb_source",
            params: {
              end_point: nil,
              source: nil,
              start_point: nil
            }
          }
        end

      end

      # @return [Array]
      def self.required_parameters
        [
          :point,
          :source,
        ]
      end
    end # ExpressionAtPoint
  end # Actions
end # Rhubarb
