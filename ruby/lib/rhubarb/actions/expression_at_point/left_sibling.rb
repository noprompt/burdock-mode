require_relative "../../ast"
require_relative "../../ast/zipper"
require_relative "processor"

module Rhubarb
  module Actions
    module ExpressionAtPoint
      module LeftSibling

        # @param [Hash] message
        # @return [Hash] message
        def self.call(message)
          params = message.fetch("params")
          point = params.fetch("point")
          source = params.fetch("source")

          processor = Rhubarb::Actions::ExpressionAtPoint::Processor.new(point)
          node = Rhubarb::AST.from_string(source)

          maybe_node = processor.process(node)
          require "pry"; binding.pry
        end

      end # LeftSibling
    end # ExpressionAtPoint
  end # Actions
end # Rhubarb
