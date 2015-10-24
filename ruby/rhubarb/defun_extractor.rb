require 'parser/current'

module Rhubarb

  class DefunExtractor < AST::Processor
    attr_reader :line

    def self.extract_defun(node, line)
      new(line).process(node)
    end

    def initialize(line)
      @line = line
    end

    def on_begin(node)
      node_on_line = ASTUtilities.find_node_on_line(node, line)

      if node_on_line
        node_on_line.updated(nil, process(node_on_line))
      else
        node
      end
    end

    def on_module(node)
      const = node.children[0]
      node_on_line = ASTUtilities.find_node_on_line(node, line)

      if node_on_line
        node.updated(nil, [const, process(node_on_line)])
      else
        node
      end
    end

    def on_class(node)
      consts = node.children.take_while do |child_node|
        # A nil indicates the absence of inheritance.
        child_node.nil? || child_node.type == :const
      end

      new_node = node.updated(nil, node.children.drop(consts.length))
      node_on_line = ASTUtilities.find_node_on_line(new_node, line)

      if node_on_line
        node.updated(nil, [*consts, process(node_on_line)])
      else
        node
      end
    end 
  end # DefunExtractor

end # Rhubarb
