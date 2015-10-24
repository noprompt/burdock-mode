require_relative 'zipper'
require 'stringio'

module Rhubarb

  module Sexp
    # @param [Object] x
    # @return [Boolean]
    def self.node?(x)
      x.is_a?(::Parser::AST::Node)
    end

    # @param [Object] node
    # @param [Fixnum] line
    # @return [Boolean]
    def self.node_contains_line?(node, line)
      return false unless node.is_a?(::Parser::AST::Node)
      return false unless line.is_a?(::Fixnum)

      location = node.location
      line.between?(location.line, location.last_line)
    rescue
      false
    end

    # @param [Object] node
    # @param [Fixnum] column
    # @return [Boolean]
    def self.node_contains_column?(node, column)
      return false unless node.is_a?(::Parser::AST::Node)
      return false unless column.is_a?(::Fixnum)

      location = node.location
      column.between?(location.column, location.last_column)
    rescue
      false
    end

    # @param [Object] node
    # @param [Fixnum] line
    # @param [Fixnum] column
    # @return [Boolean]
    def self.node_contains_coordinates?(node, line, column)
      node_contains_line?(node, line) && node_contains_column?(node, column)
    end

    # @param [Object] node
    # @param [Fixnum] point
    # @return [Boolean]
    def self.node_contains_point?(node, point)
      return false unless node.is_a?(::Parser::AST::Node)
      return false unless point.is_a?(::Fixnum)

      expression = node.location.expression
      return false unless expression

      point.between?(expression.begin_pos, expression.end_pos)
    end

    # @param [Parser::AST::Node] node
    # @param [Fixnum] line
    # @param [Fixnum] column
    # @return [Parser::AST::Node] if the node was found.
    # @return [NilClass] if the node was not found.
    def self.find_node_at_coordinates(node, line, column)
      z = ::Rhubarb::Zipper.new(node)
      found_node = nil

      loop do
        break if z.done?

        if node?(z.node) && node_contains_coordinates?(z.node, line, column)
          found_node = z.node
        end
        z = z.next
      end

      found_node
    end

    # @param [Parser::AST::Node] node
    # @param [Fixnum] point
    # @return [Rhubarb::Zipper] if a zipper location could be derived.
    # @return [NilClass] if a zipper location could not be derived. 
    def self.zipper_location_at_point(node, point)
      point = point.pred
      z = ::Rhubarb::Zipper.new(node)
      found_loc = nil

      loop do
        break if z.done?

        if node?(z.node) && node_contains_point?(z.node, point)
          found_loc = z
        end
        z = z.next
      end

      found_loc
    end

    # @param [Parser::AST::Node] node
    # @param [Fixnum] point
    # @return [Parser::AST::Node] if the node was found.
    # @return [NilClass] if the node was not found.
    def self.find_node_at_point(node, point)
      z = zipper_location_at_point(node, point)
      if z
        z.node
      end
    end

    # @param [Parser::AST::Node] node
    # @yieldparam [Rhubarb::Zipper] zipper current zipper location
    # @yieldreturn [Object, Boolean, nil] whether the zipper location
    #   satisfies the predicate.
    # @return [Rhubarb::Zipper] if a zipper location could be found.
    # @return [nil] if a zipper location could not be found.
    def self.find_zipper_location(node, &predicate)
      z = ::Rhubarb::Zipper.new(node)
      found_loc = nil

      loop do
        break if z.done?

        if yield z
          found_loc = z
          break
        else
          z = z.next
        end
      end

      found_loc
    end


  end # Sexp

end # Rhubarb
