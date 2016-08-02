require "ast"
require "burdock/refinements/ast"

module Burdock
  module Actions
    module ScopeAtLine
      class Processor < ::AST::Processor

        using Burdock::Refinements::AST

        # @!attribute [r] line_number
        #  @return [Integer]
        attr_reader :line_number

        # @param [Integer] line_number
        def initialize(line_number)
          @line_number = line_number
        end

        # @param [AST::Node] node
        # @return [AST::Node] the original `begin` node or the node
        #   found on {line_number}.
        # @note This is not responsible for processing Ruby's
        #   `begin` construct.
        def on_begin(node)
          children = node.children
          maybe_node = find_node_on_line(children)

          if maybe_node
            new_node = process(maybe_node)
            # Since we're only interested in finding a single node we
            # return just the processed node we've found instead of an
            # updated node with one child.
            new_node
          else
            node
          end
        end

        # @param [AST::Node] node
        # @return [AST::Node] the original `class` node or a new
        #   `class` node containing only the original constant nodes
        #   and the child node found on {line_number}.
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
        # @return [AST::Node] the original `module` node or a new
        #   `module` node containing only the original constant node
        #   and the child node found on {line_number}.
        def on_module(node)
          constant = node.children.first
          children = node.children.drop(1)

          maybe_node = find_node_on_line(children)

          if maybe_node
            new_child = process(maybe_node)
            new_children = [constant, new_child]
            node.updated(nil, new_children)
          else
            node
          end
        end

        # @param [Array] nodes
        # @return [AST::Node] if a node on {line_number} could be
        #   found.
        # @return [nil] if a node on {line_number} could not be
        #   found.
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
