require "ast"

module Rhubarb
  module AST
    module Zipper
      require_relative "zipper/location"

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
    end # Zipper
  end # AST
end # Rhubarb
