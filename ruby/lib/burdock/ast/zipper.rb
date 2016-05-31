require "ast"
require "burdock/refinements/ast"
require "burdock/ast/zipper/location"

module Burdock
  module AST
    module Zipper
      using Burdock::Refinements::AST

      # @param [AST::Node]
      def self.from_node(node)
        case node
        when ::AST::Node
          Location.new(node, nil, [], [])
        else
          message_template = <<ERROR_MESSAGE
expected argument to be an instance of AST::Node but instead received %s
ERROR_MESSAGE
          message = message_template % [node.class]

          fail ArgumentError, message
        end
      end

      # @param [Burdock::Zipper::Location] location
      # @param [Integer] point
      # @return [Burdock::Zipper::Location]
      def self.location_at_point(location, point)
        maybe_location = location.child_locations.find do |child_location|
          child_node = child_location.node
          case child_node
          when ::AST::Node
            child_node.contains_point?(point)
          end
        end

        if maybe_location
          location_at_point(maybe_location, point)
        else
          location
        end
      end
      
    end # Zipper
  end # AST
end # Burdock
