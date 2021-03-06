require "burdock/actions/registry"
require "burdock/ast/zipper" 
require "burdock/refinements/ast"
require "burdock/refinements/object"


module Burdock
  module Actions
    module ZipDown
      using Burdock::Refinements::AST
      using Burdock::Refinements::Object

      # @param [Hash] message
      # @return [Hash]
      def self.call(message)
        params = message.fetch("params")
        point = params.fetch("point")
        source = params.fetch("source")

        node = Burdock::AST.from_string(source)
        root_location = Burdock::AST::Zipper.from_node(node)

        location = Burdock::AST::Zipper.location_at_point(root_location, point)
        maybe_child_node =
          if location.branch?
            location.children.find do |child|
              child.node?
            end
          end

        if maybe_child_node
          expression = maybe_child_node.location.expression
          start_line = expression.first_line
          start_point = expression.begin_pos
          end_point = expression.end_pos
          end_line = expression.last_line
          ruby_source = source[start_point...end_point]

          {
            method: "burdock/source",
            params: {
              end_line: end_line,
              end_point: end_point,
              source: ruby_source,
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
    end # ZipUp
  end # Actions
end # Burdock

Burdock::Actions::Registry.put("burdock/zip-down", Burdock::Actions::ZipDown)
