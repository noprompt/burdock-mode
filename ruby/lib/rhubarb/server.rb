require "json"

require_relative "actions/echo"
require_relative "actions/expression_at_point"
require_relative "actions/scope_at_line"
require_relative "response"
require_relative "result"
  

module Rhubarb
  class Server

    # @return [nil]
    def run
      while line = $stdin.gets
        response = handle_request(line)
        puts response
      end
    end

    # @param [String] request
    # @return [String]
    def handle_request(request)
      Rhubarb::Result.try do
        message = parse_message(request)
        handle_message(message)
      end.otherwise do |error|
        Rhubarb::Response.from_exception(error)
      end.then do |hash|
        hash.to_json
      end.value
    end

    # @param [Hash] message
    # @return [Hash]
    def handle_message(message)
      Rhubarb::Result.try do
        id = message.fetch("id")
        method = message.fetch("method")
        params = message.fetch("params")

        case method
        when "rhubarb_echo"
          Rhubarb::Actions::Echo.call(message)
        when "rhubarb_expression_at_point"
          Rhubarb::Actions::ExpressionAtPoint.call(message)
        when "rhubarb_scope_at_line"
          Rhubarb::Actions::ScopeAtLine.call(message)
        end
      end.otherwise do |error|
        Rhubarb::Response.from_exception(error)
      end.value
    end

    # @param [String] request
    # @return [String]
    def parse_message(request)
      JSON.parse(request)
    end

  end # Server
end # Rhubarb
