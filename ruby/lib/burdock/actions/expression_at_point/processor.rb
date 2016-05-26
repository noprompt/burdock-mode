require "ast"
require "burdock/refinements/ast"

module Burdock
  module Actions
    module ExpressionAtPoint
      class Processor < ::AST::Processor

        using Burdock::Refinements::AST

        attr_reader :point

        # @param [Integer] point
        def initialize(point)
          @point = point
        end

        # @param [AST::Node, Object] node
        # @return [AST::Node, Object]
        def process(node)
          case node
          when ::AST::Node
            if node.contains_point?(self.point)
              maybe_child_node = process_all(node.children).find do |child_node|
                case child_node
                when ::AST::Node
                  child_node
                end
              end

              maybe_child_node || node
            end
          else
            node
          end
        end

      end # Processor
    end # ExpressionAtPoint
  end # Actions
end # Burdock
