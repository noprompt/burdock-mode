require "json"
require "logger"
require "burdock/actions/echo"
require "burdock/actions/expression_at_point"
require "burdock/actions/left_sibling"
require "burdock/actions/right_sibling"
require "burdock/actions/s_expression_at_point"
require "burdock/actions/scope_at_line"
require "burdock/actions/zip_down"
require "burdock/actions/zip_up"
require "burdock/environment"
require "burdock/response"

module Burdock
  module REPL

    HandlerMissingError = Class.new(StandardError)

    DEFAULT_HANDLERS = {
      "burdock/echo" => Burdock::Actions::Echo,
      "burdock/expression-at-point" => Burdock::Actions::ExpressionAtPoint,
      "burdock/s-expression-at-point" => Burdock::Actions::SExpressionAtPoint,
      "burdock/zip-left" => Burdock::Actions::LeftSibling,
      "burdock/zip-right" => Burdock::Actions::RightSibling,
      "burdock/zip-up" => Burdock::Actions::ZipUp,
      "burdock/zip-down" => Burdock::Actions::ZipDown,
      "burdock/scope-at-line" => Burdock::Actions::ScopeAtLine,
    }

    LOG_FILE = File.expand_path(File.join(File.dirname(__FILE__), "../../log/burdock-next.log"))

    def self.logger
      @logger ||= lambda do
        logger = ::Logger.new(LOG_FILE, "daily")
        logger.formatter = lambda do |severity, datetime, _, message|
          log_data = {
            datetime: datetime,
            severity: severity,
            message: message
          }

          log_data.to_json + "\n"
        end

        logger
      end.call
    end

    def self.handlers
      DEFAULT_HANDLERS
    end

    # @param [Hash] message
    # @return [Hash]
    def self.handle_message(message)
      id = message.fetch("id")
      method = message.fetch("method")
      params = message.fetch("params")

      maybe_handler = self.handlers.fetch(method, nil)

      if maybe_handler
        maybe_handler.call(message)
      else
        error_message = "No handler for method type `%s'" % [method]
        error = HandlerMissingError.new(error_message)
        Burdock::Response.from_exception(error)
      end
    rescue => error
      Burdock::Response.from_exception(error)
    end

    # @param [String] request
    # @return [String]
    def self.handle_request(request)
      parse_message(request) do |result|
        case result
        when StandardError
          Burdock::Response.from_exception(result)
        else
          message = result
          id_data = { "id" => message["id"] }
          handle_message(message).merge(id_data).to_json
        end
      end
    end

    # @param [String] request
    # @return [Hash]
    def self.parse_message(request)
      value =
        begin
          json = JSON.parse(request)
          json["id"] ||= SecureRandom.uuid
          json
        rescue => error
          error
        end

      yield value
    end

    # @return [nil]
    def self.run!(client: "emacs")
      initialization_data = {
        method: "burdock/initialize",
        params: {
          client: client
        }
      }

      logger.info(initialization_data.to_json)

      loop do
        line = $stdin.gets
        logger.info(line)
        response = handle_request(line)
        logger.info(response)

        case client
        when "emacs"
          $stderr.puts(response)
        else
          $stdout.puts(response)
        end
      end
    end

  end # REPL
end # Burdock
