require_relative 'buffer'

module Rhubarb

  class BufferManager
    attr_reader :buffers

    def initialize
      @buffers = {}
    end

    # @param [String] buffer_id
    # @param [String] buffer_content
    def initialize_buffer(buffer_id, buffer_content)
      @buffers[buffer_id] = buffer_content
    end

    # @param [String] buffer_id the buffer id to retrieve.
    # @return [String] the buffer content.
    def get_buffer(buffer_id)
      @buffers.fetch(buffer_id)
    end

  end

end
