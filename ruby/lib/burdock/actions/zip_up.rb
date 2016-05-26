require "burdock/actions/registry"
require "burdock/ast/zipper" 
require "burdock/refinements/ast"
require "burdock/refinements/object"


module Burdock
  module Actions
    module ZipUp
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

        parent_location =
          if location.root?
            location
          else
            location = location.up

            loop do
              case true
              when location.root?
                break
              when location.node.type == :begin
                location = location.up
              else
                break
              end
            end

            location
          end

        parent_node = parent_location.node
        expression = parent_node.location.expression
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
      end
    end # ZipUp
  end # Actions
end # Burdock

Burdock::Actions::Registry.put("burdock/zip-up", Burdock::Actions::ZipUp)
