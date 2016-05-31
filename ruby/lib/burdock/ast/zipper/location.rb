module Burdock
  module AST
    module Zipper
      ZipperError = Class.new(StandardError)

      class Location
        # @!attribute [r] path
        #   @return [Burdock::AST::Zipper::Location] the path (from
        #     the root) to this location.
        #   @return [nil] if this location is at the root.
        attr_reader :path

        # @!attribute [r] node
        #   @return [AST::Node] the value of the node at this
        #     location
        attr_reader :node

        # @!attribute [r] lefts
        #   @return [Array] the siblings to the left at this
        #     location
        attr_reader :lefts

        # @!attribute [r] rights
        #   @return [Array] the siblings to the right at this
        #     location
        attr_reader :rights

        # @param [AST::Node] node
        # @param [Burdock::AST::Zipper::Location, nil] path
        # @param [Array] lefts
        # @param [Array] rigths
        def initialize(node, path, lefts = [], rights = [])
          @node = node
          @path = path
          @lefts = lefts
          @rights = rights
        end

        def ==(other)
          case other
          when Location
            other.node == self.node &&
              other.path == self.path &&
                other.lefts == self.lefts &&
                  other.rights == self.rights
          else
            false
          end
        end

        # @return [Boolean]
        def root?
          self.path.nil?
        end

        # @return [Boolean]
        def branch?
          self.node.is_a?(::AST::Node)
        end

        # @return [Array]
        def children
          if branch?
            self.node.children
          else
            fail ZipperError, "`children' may only be called on a branch location (when the value of `node' is an AST::Node)"
          end
        end

        # Move up to the parent location applying any changes to the
        # node at this location. This method is a noop if this
        # location is the root location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def up
          if root?
            fail ZipperError, "`up' may not be called on the root location"
          else
            new_children = self.lefts.to_a + [self.node] + self.rights.to_a
            parent_node = self.path.node
            node = parent_node.updated(nil, new_children)

            self.class.new(node, self.path.path, self.path.lefts, self.path.rights)
          end
        end

        # Move down from the parent location. This method is a noop
        # if this location is not a branch node (e.g. an `AST::Node`).
        #
        # @return [Burdock::AST::Zipper::Location]
        def down
          if branch?
            head, *rights = children
            lefts = []
            self.class.new(head, self, lefts, rights)
          else
            fail ZipperError, "`down' may only be called on a branch location (when the value of `node' is an AST::Node)"
          end
        end

        # Move to the node right of this location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def right
          if self.rights.any?
            node, *new_rights = self.rights
            new_lefts = self.lefts + [self.node]

            self.class.new(node, self.path, new_lefts, new_rights)
          else
            # @note I don't like this...
            nil
          end
        end

        # Move to the node rightmost of this location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def rightmost
          maybe_right = self.right
          if maybe_right
            maybe_right.rightmost
          else
            self
          end
        end

        # Move to the node left of this location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def left
          if self.lefts.any?
            *new_lefts, node = self.lefts 
            new_rights = [self.node] + self.rights

            self.class.new(node, self.path, new_lefts, new_rights)
          else
            # @note I don't like this...
            nil
          end
        end

        # Move to the node leftmost of this location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def leftmost
          maybe_left = self.left
          if maybe_left
            maybe_left.leftmost
          else
            self
          end
        end

        # @yieldparam [Object] node the node at this location.
        # @yieldreturn [Object] the new node at this locaiton.
        # @return [Burdock::AST::Zipper::Location]
        def edit
          new_node = yield self.node

          self.class.new(new_node, self.path, self.lefts, self.rights)
        end

        # Replace the node at this location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def replace(x)
          edit { x }
        end

        # Delete the current node.
        #
        # If there are any nodes to the right of this location,
        # delete the current node and move to the node to the right
        # of this one.
        #
        # If there are no nodes to the right of this location but
        # there are nodes to the left, delete the current node and
        # move to the left of this one.
        #
        # If there are no nodes to the left or right of this location
        # then delete the current node and move up to the parent.
        #
        # @return [Burdock::AST::Zipper::Location]
        def delete
          if root?
            fail ZipperError, "the root not may not be deleted"
          else
            if self.rights.any?
              new_node, *new_rights = self.rights

              self.class.new(new_node, self.path, self.lefts, new_rights)
            else
              if self.lefts.any?
                *new_lefts, new_node = self.lefts

                self.class.new(new_node, self.path, new_lefts, self.rights)
              else
                up_node = self.path.node
                new_up_node = up_node.updated(nil, [])

                if self.path.root?
                  self.class.new(new_up_node, nil, nil, nil)
                else
                  parent_path = self.path.path
                  new_lefts = parent_path.left
                  new_rights = parent_path.rights

                  self.class.new(new_up_node, parent_path, new_lefts, new_rights)
                end
              end
            end
          end
        end

        # Insert a node to the "left" of this location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def insert_left(x)
          if root?
            fail ZipperError, "insertion is not permitted at the root"
          else
            new_lefts = self.lefts + [x]

            self.class.new(self.node, self.path, new_lefts, self.rights)
          end
        end

        # Insert a node to the "right" of this location.
        #
        # @return [Burdock::AST::Zipper::Location]
        def insert_right(x)
          if root?
            fail ZipperError, "insertion is not permitted at the root"
          else
            new_rights = self.rights + [x]

            self.class.new(self.node, self.path, self.lefts, new_rights)
          end
        end

        # @return [Burdock::AST::Zipper::Location]
        def root
          if root?
            self
          else
            up
          end
        end

        # Return an array of all child locations of this location.
        #
        # @return [Array<Burdock::AST::Zipper:::Location>]
        def child_locations
          if self.branch?
            if self.children.any?
              child_location = self.down
              child_location
                .right_locations
                .tap { |locations| locations.unshift(child_location) }
            else
              []
            end
          else
            fail ZipperError, "`child_locations' may only be called on a branch location (when the value of `node' is an AST::Node)"
          end
        end

        # Return an array of sibling locations to the right of this
        # location.
        #
        # @return [Array<Burdock::AST::Zipper:::Location>]
        def right_locations
          right_location = self.right

          if self.right
            right_location
              .right_locations
              .tap { |locations| locations.unshift(right_location)}
          else
            []
          end
        end

        # Return an array of sibling locations to the left of this
        # location.
        #
        # @return [Array<Burdock::AST::Zipper:::Location>]
        def left_locations
          maybe_left = self.left

          if maybe_left
            maybe_left
              .left_locations
              .tap { |locations| locations.push(maybe_left) }
          else
            []
          end
        end

        # Applies `block` to each node of the tree in pre-order
        # fashion returning.
        #
        # @yieldparam [AST::Node, Object]
        # @return [Burdock::AST::Zipper::Location] the root location
        #   after applying the prewalk function to each node.
        def prewalk(&block)
          new_location =
            if self.branch?
              sub_location = self.edit(&block)

              if sub_location.branch?
                sub_location
                  .down
                  .prewalk(&block)
              else
                sub_location
              end
            else
              self.edit(&block)
            end

          maybe_right = new_location.right

          if maybe_right
            maybe_right.prewalk(&block)
          else
            if new_location.root?
              new_location
            else
              new_location.up
            end
          end
        end

        # Applies `block` to each node of the tree in post-order
        # fashion returning.
        #
        # @yieldparam [AST::Node, Object]
        # @return [Burdock::AST::Zipper::Location] the root location
        #   after applying the prewalk function to each node.
        def postwalk(&block)
          new_location =
            if self.branch?
              self
                .down
                .postwalk(&block)
                .edit(&block)
            else
              self.edit(&block)
            end

          maybe_right = new_location.right

          if maybe_right
            maybe_right.postwalk(&block)
          else
            if new_location.root?
              new_location
            else
              new_location.up
            end
          end
        end

        def each
          if block_given?
            to_enum.each do |node|
              yield node
            end
          else
            to_enum
          end
        end

        # Return an instance of Enumerator which produces a stream of
        # nodes reachable from this location in level-order fashion.
        #
        # @return [Enumerator]
        def to_enum
          Enumerator.new do |yielder|
            if self.branch?
              queue = [self]

              loop do
                if queue.empty?
                  break
                else
                  location = queue.shift

                  if location.branch?
                    yielder << location.node
                    queue.concat(location.child_locations)
                  else
                    yielder << location.node
                  end
                end
              end
            else
              yielder << self.node
            end
          end
        end

      end # Location
    end # Zipper
  end # AST
end
