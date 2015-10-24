require 'securerandom'
require 'logger'
require_relative 'response'
require_relative 'session'
require_relative 'null'

module Rhubarb

  class Server

    def initialize(handler: nil, log_file: nil)
      @session = Session.new
      @handler = handler.new(@session)

      if log_file
        @logger = Logger.new(log_file) 
        @logger.formatter = proc do |severity, datetime, progname, message|
          json = JSON.generate({
              severity: severity,
              datetime: datetime,
              message: message
            })
          json << "\n"
        end
      else
        @logger = ::Rhubarb::Null
      end
    end

    def accept
      ::Rhubarb::Response.message_response("Rhubarb initialized")

      while message = $stdin.gets()
        @logger.info(message)

        begin
          request = JSON.parse(message, symbolize_names: false)
          id, method, params = request.values_at('id', 'method', 'params')
          response = @handler.dispatch(method, params)
        rescue Exception => exception
          response = ::Rhubarb::Response.from_exception(exception)
        end

        response ||=  ::Rhubarb::Response.noop_response
        response[:id] = id
        respond(response)
      end
    end

    def respond(id: nil, result: nil, error: nil)
      response_string = JSON.generate({id: id, result: result, error: error})

      if error
        @logger.error(response_string)
      else
        @logger.info(response_string)
      end

      STDERR.puts(response_string)
    end

    def start!
      begin
        accept
      rescue Exception => exception
        response = ::Rhubarb::Response.from_exception(exception)
        respond(response)
      end
    end

  end # Server

end # Rhubarb
