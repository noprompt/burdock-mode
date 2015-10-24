require 'parser/current'

module Rhubarb

  class Zipper
    attr_reader :node
    attr_reader :path
    attr_reader :parent_nodes

    def initialize(node, lefts = [], rights = [], parent_nodes = [], path = nil, done = false)
      @node = node
      @lefts = lefts.freeze
      @rights = rights.freeze
      @path = path
      @parent_nodes = parent_nodes.freeze
      @done = done
    end

    def branch?
      node.is_a?(::Parser::AST::Node)
    end

    def children
      node.children
    end

    def make_node(new_children)
      node.updated(nil, new_children)
    end

    def lefts
      @lefts.dup
    end

    def rights
      @rights.dup
    end

    def down
      if branch?
        if children.any?
          new_node, *new_rights = children
          new_path = self
          new_parent_nodes =
            if path
              path.parent_nodes.dup.push(node)
            else
              [node]
            end
          self.class.new(new_node, [], new_rights, new_parent_nodes, new_path)
        end
      end
    end

    def up
      if parent_nodes.any?
        parent_node = parent_nodes.last
        parent_node = path.make_node(lefts.push(node).concat(rights))
        self.class.new(parent_node, path.lefts, path.rights, path.parent_nodes, path.path)  
      end
    end

    def root
      if up.nil?
        node
      else
        up.root
      end
    end

    def right
      if rights.any?
        new_node, *new_rights = rights
        new_lefts = lefts.push(node)
        self.class.new(new_node, new_lefts, new_rights, parent_nodes, path)
      end
    end

    def rightmost
      new_rights = []
      *new_lefts, new_node = rights
      new_lefts = lefts.push(node).concat(new_lefts)
      self.class.new(new_node, new_lefts, new_rights, parent_nodes, path)
    end

    def left
      *new_lefts, new_node = lefts
      new_rights = rights.unshift(node)
      self.class.new(new_node, new_lefts, new_rights, parent_nodes, path)
    end

    def leftmost
      new_lefts = []
      new_node, *new_rights = lefts
      new_rights = new_rights.concat(rights.unshift(node))
      self.class.new(new_node, new_lefts, new_rights, parent_nodes, path)
    end

    def insert_left(sibling)
      if !path
        throw Exception.new("Insert at top")
      else
        new_lefts = lefts.push(sibling)
        self.class.new(node, new_lefts, rights, parent_nodes, path)
      end
    end

    def insert_right(sibling)
      if !path
        throw Exception.new("Insert at top")
      else
        new_rights = rights.unshift(sibling)
        self.class.new(node, lefts, new_rights, parent_nodes, path)
      end
    end

    def replace(new_node)
      self.class.new(new_node, lefts, rights, parent_nodes, path)
    end

    def edit(&block)
      new_node = block[node]
      replace(new_node)
    end

    # Inserts the item as the leftmost child of the node at this location,
    # without moving.
    def insert_child(child)
      replace(make_node(children.dup.unshift(child)))
    end

    # Inserts the item as the rightmost child of the node at this loc,
    # without moving.
    def append_child(child)
      replace(make_node(children.dup.push(child)))
    end

    def done?
      @done
    end

    def next
      if done?
        self
      else
        if branch? && down
          down
        elsif right
          right
        else
          next_until_done
        end
      end
    end

    def next_until_done
      zipper = self

      loop do
        if zipper.up
          if zipper.up.right
            zipper = zipper.up.right
            break
          else
            zipper = zipper.up
          end
        else
          zipper = self.class.new(zipper.node, zipper.lefts, zipper.rights, zipper.parent_nodes, zipper.path, true)
          break
        end
      end

      zipper
    end

    private :next_until_done

    def prev
    end

    # Removes the node at loc, returning the loc that would have
    # preceded it in a depth-first walk.
    def remove
      if path.nil?
        raise Exception.new("Remove at top")
      else
        if lefts.count > 0
          *new_lefts, new_node = lefts
          self.class.new(new_node, new_lefts, rights, parent_nodes, path)
        else
          up.edit do |node|
            new_children = node.children[1..-1]
            node.updated(nil, new_children)
          end.next
        end
      end
    end

  end # Zipper

end # Rhubarb
