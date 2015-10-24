require_relative 'parser'

module Rhubarb

  class Buffer
    attr_reader :id
    attr_reader :contents

    def initialize(id, contents)
      @id = id
      @contents = contents
    end

    def update(start_point, end_point, length, value)
      a = start_point.pred
      b = start_point.pred + length

      head = @contents[0...a].to_s
      tail = @contents[b..-1].to_s

      @contents = head + value + tail
      @ast_node = nil
      @error = nil
      @contents
    end

    # @return [Parser::AST::Node]
    # @return [NilClass]
    def ast_node
      attempt_parse
      @ast_node
    end

    # @return [Exception]
    # @return [NilClass]
    def error
      attempt_parse
      @error
    end

    def attempt_parse
      unless @ast_node
        begin
          @ast_node = ::Rhubarb::Parser.parse(@contents)
          @error = nil
        rescue ::Parser::SyntaxError => error
          @error = error
          @ast_node = nil
        end
      end
    end
    private :attempt_parse

  end # Buffer

end # Rhubarb
