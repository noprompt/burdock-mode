require "json"
require "securerandom"
require "yajl"


require_relative "actions/echo"
require_relative "actions/expression_at_point"
require_relative "actions/scope_at_line"
require_relative "response"
require_relative "result"
  

module Burdock
  HandlerMissingError = Class.new(StandardError)

  class Server

    attr_reader :handlers

    def initialize(handlers = Burdock::Defaults.handlers)
      @handlers = handlers
    end

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
      response =
        begin
          message = parse_message(request)
          handle_message(message)
        rescue => error
          Burdock::Response.from_exception(error)
        end
      response.merge({ id: message["id"] }).to_json
    end

    # @param [Hash] message
    # @return [Hash]
    def handle_message(message)
      id = message.fetch("id")
      method = message.fetch("method")
      params = message.fetch("params")

      maybe_handler = self.handlers.fetch(method, nil)

      if maybe_handler
        maybe_handler.call(message)
      else
        error_message = "No handler for method type `%s'" % [method]
        error = Burdock::HandlerMissingError.new(error_message)
        Burdock::Response.from_exception(error)
      end
    rescue => error
      Burdock::Response.from_exception(error)
    end

    # @param [String] request
    # @return [Hash]
    def parse_message(request)
      json = JSON.parse(request)
      json["id"] ||= SecureRandom.uuid
      json
    end

  end # Server
end # Burdock
