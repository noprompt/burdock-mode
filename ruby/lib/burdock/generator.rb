module Burdock

  # @see http://rubinius.com/doc/en/virtual-machine/instructions/
  class Generator

    # @!attribute [r] stack
    # @return [Array]
    attr_reader :stack

    # @!attribute [r] instruction_pointer
    # @return [Integer]
    attr_reader :instruction_pointer

    # @!attribute [r] label_mapping
    # @return [Hash<String => Integer>]
    attr_reader :label_mapping

    def initialize
      @instruction_pointer = 0
      @label_mapping = {}
      @stack = []
    end

    # @param [Object]
    # @return [self]
    def make_label(label_name)
      self.label_mapping[label_name] = self.instruction_pointer
      self
    end

    # @return [self]
    def push_nil
      self.stack.push([:nil])
      self
    end

    # @return [self]
    def push_true
      self.stack.push([:true])
      self
    end

    # @return [self]
    def push_false
      self.stack.push([:false])
      self
    end

    # @return [self]
    def push_self
      self.stack.push([:self])
      self
    end

    # @return [self]
    def push_int(int)
      self.stack.push([:int, int])
      self
    end

    # @return [self]
    def push_str(str)
      self.stack.push([:str, str])
      self
    end

    # @return [self]
    def push_sym(sym)
      self.stack.push([:sym, sym])
      self
    end

    # @return [self]
    def push_ivar(sym)
      self.stack.push([:ivar, sym])
      self
    end

    def set_ivar(sym)
      v = pop_and_return
      self.stack.push([:ivasgn, sym, v])
      self
    end

    def push_const(sym)
      self.stack.push([:const, [:cbase], sym])
      self
    end

    def push_scope
      self
    end

    def find_const(sym)
      v = pop_and_return

      if v
        if v.first == :const
          self.stack.push([:const, v, sym])
          self
        else
          self.stack.push(v)
          push_const(sym)
        end
      else
        push_const(sym)
      end
    end

    # @return [self]
    def make_array(count)
      self.stack.push([:array, *pop_and_return_many(count)])
      self
    end

    # @param [Symbol] method_name
    # @return [self]
    def send_method(method_name)
      receiver = pop_and_return
      self.stack.push([:send, receiver, method_name])
      self
    end

    # @param [Symbol] method_name
    # @param [Integer] count
    # @return [self]
    def send_stack(method_name, count)
      receiver = pop_and_return
      arguments = pop_and_return_many(count)
      self.stack.push([:send, receiver, method_name, *arguments])
      self
    end

    # Swaps the top two values on the stack such that the second
    # value becomes the first and the first value becomes the
    # second.
    #
    # @return [self]
    def swap_stack
      v1, v2 = self.stack.pop, self.stack.pop
      if v1
        if v2
          self.stack.push(v1)
          self.stack.push(v2)
          self
        else
          self.stack.push(v1)
          self
        end
      else
        self
      end
    end

    # Read a value from the top of the stack and push it on the
    # stack again without removing the original value.
    # @return [self]
    def dup_top
      v = self.stack.pop

      if v
        self.stack.push(v)
        self.stack.push(v.dup)
        self
      else
        self
      end
    end

    def dup_many(count)
      count.times { dup_top }
      self
    end

    def pop
      self.stack.pop
      self
    end

    def pop_many(count)
      count.times { pop }
      self
    end

    private

    def pop_and_return
      self.stack.pop
    end

    def pop_and_return_many(count)
      count.times.map { pop_and_return }
    end

  end

end
