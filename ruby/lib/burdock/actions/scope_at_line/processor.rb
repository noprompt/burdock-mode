require "ast"
require "burdock/refinements/ast"

module Burdock
  module Actions
    module ScopeAtLine
      class Processor < ::AST::Processor

        using Burdock::Refinements::AST

        attr_reader :line_number

        # @param [Integer] line_number
        def initialize(line_number)
          @line_number = line_number
        end

        # @param [AST::Node] node
        # @return [AST::Node]
        def on_begin(node)
          children = node.children
          maybe_node = find_node_on_line(children)

          if maybe_node
            new_child = process(maybe_node)
            new_children = [new_child]
            node.updated(nil, new_children)
          else
            node
          end
        end

        # @param [AST::Node] node
        # @return [AST::Node]
        def on_class(node)
          constants = node.children.take(2)
          children = node.children.drop(2)

          maybe_node = find_node_on_line(children)

          if maybe_node
            new_child = process(maybe_node)
            new_children = [*constants, new_child]
            node.updated(nil, new_children)
          else
            node
          end
        end

        # @param [AST::Node] node
        # @return [AST::Node]
        def on_module(node)
          constant = node.children.first
          children = node.children.drop(1)

          maybe_node = find_node_on_line(children)

          if maybe_node
            new_children = [constant, maybe_node]
            node.updated(nil, children)
          else
            node
          end
        end

        # @param [Array]
        # @return [AST::Node]
        # @return [nil]
        def find_node_on_line(nodes)
          nodes.find do |node|
            case node
            when ::AST::Node
              node.contains_line?(self.line_number)
            end
          end
        end

      end # Processor
    end # ScopeAtLine
  end # Actions
end # Burdock
