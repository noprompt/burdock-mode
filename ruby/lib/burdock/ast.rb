require "burdock/ast/zipper"
require "burdock/parser"
require "burdock/unparser"

module Burdock
  module AST

    # @param [Array] array
    # @return [Parser::AST::Node]
    def self.from_array(array)
      node_name, *xs = array 
      node_type = node_name.to_sym
      children = xs.map { |x| x.is_a?(Array) ? from_array(x) : x }
      ::Parser::AST::Node.new(node_type, children)
    end

    # @param [String] string
    # @return [Parser::AST::Node]
    def self.from_string(string)
      ::Parser::CurrentRuby.parse(string)
    end

    # @param [Parser::AST::Node]
    # @return [Array]
    def self.to_array(node)
      node_type, children = node.type, node.children
      xs = children.map { |x| x.is_a?(::Parser::AST::Node) ? to_array(x) : x }
      [node_type, *xs]
    end

    # @param [Parser::AST::Node]
    # @return [Array]
    def self.to_string(node)
      ::Unparser.unparse(node)
    end

  end # AST
end # Burdock
