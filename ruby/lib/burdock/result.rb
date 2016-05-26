module Burdock
  class Result
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def self.try(&block)
      Success.new(block.call)
    rescue StandardError => e
      Failure.new(e)
    end

    def self.succeed(value)
      Success.new(value)
    end

    def self.fail(value)
      Failure.new(value)
    end

    class Success < Result
      def success?
        true
      end

      def failure?
        false
      end

      def then(&block)
        Result.try { block.call(self.value) }
      end

      def otherwise(&_block)
        self
      end
    end

    class Failure < Result
      def success?
        false
      end

      def failure?
        true
      end

      def then(&_block)
        self
      end

      def otherwise(&block)
        Result.try { block.call(self.value) }
      end
    end

  end # Result
end # Burdock
