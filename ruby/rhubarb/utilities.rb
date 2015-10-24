require 'parser/current'

module Rhubarb

  module ASTUtilities

    def self.node?(x)
      x.is_a?(::Parser::AST::Node)
    end

    def self.node_of_type?(x, type)
      node?(x) && x.type == type
    end

    def self.expression_node?(x)
      node?(x) && !x.loc.expression.nil?
    end

    def self.node_contains_line?(node, line)
      expression_node?(node) && line.between?(node.loc.line, node.loc.last_line)
    end

    def self.node_contains_column?(node, column)
      expression_node?(node) && column.between?(node.loc.column, node.loc.last_column)
    end
    
    def self.node_contains_position?(node, line, column)
      node_contains_line?(node, line) && node_contains_column?(node, column)
    end

    def self.find_node_on_line(node, line)
      if node?(node)
        node.children.find do |child_node|
          node_contains_line?(child_node, line)
        end
      end
    end

  end # ASTUtilities

end # Rhubarb
