require "json"
require "logger"
require "burdock/actions"
require "burdock/actions/registry"
require "burdock/environment"
require "burdock/response"

module Burdock
  module REPL

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

    # @param [Hash] message
    # @return [Hash]
    def self.handle_message(message)
      id = message.fetch("id")
      method = message.fetch("method")
      params = message.fetch("params")

      Burdock::Actions::Registry.get(method) do |result|
        case result
        when StandardError
          Burdock::Response.from_exception(error)
        else
          result.call(message)
        end
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
          $stderr.write(response)
          $stderr.write("\0\0")
        else
          $stdout.puts(response)
          $stderr.write("\0\0")
        end
      end
    end

  end # REPL
end # Burdock
