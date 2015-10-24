require 'securerandom'
require 'parser/current'
require_relative 'buffer'

module Rhubarb

  class Session
    attr_reader :id

    def initialize
      @id = SecureRandom.uuid
      @state = {
        buffers: {}
      }
    end

    # @param [Object] key
    # @return [Object]
    def [](key)
      @state[key]
    end

    # @param [Object] key
    # @param [Object] value
    # @return [Object]
    def []=(key, value)
      @state[key] = value
    end

    def initialize_buffer(buffer_id, buffer_contents)
      buffer = Buffer.new(buffer_id, buffer_contents)
      @state[:buffers][buffer_id] = buffer
    end

    def get_buffer(buffer_id)
      @state[:buffers][buffer_id]
    end

    def update_buffer(params)
      buffer_id = params.fetch('buffer-id')
      buffer = get_buffer(buffer_id)

      update_buffer_args = params.values_at('start-point', 'end-point', 'length', 'value')
      buffer.update(*update_buffer_args)
    end

    def get_buffer_ast_node(buffer_id, &block)
      buffer = get_buffer(buffer_id)
      yield(buffer.ast_node, buffer.error)
    end
  end # Session

end # Rhubarb
