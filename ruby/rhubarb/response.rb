module Rhubarb

  module Response
    # @param [Hash] hash
    def self.error_response(hash)
      { error: hash }
    end

    # @param [Exception] exception
    def self.from_exception(exception)
      case exception
      when ::Parser::SyntaxError
        diagnostic = exception.diagnostic
        exception_location = diagnostic.location
        exception_line_start = exception_location.line
        exception_line_end = exception_location.last_line
        exception_column_start = exception_location.column
        exception_column_end = exception_location.last_column

        error_response({
            message: exception.message,
            trace: exception.backtrace,
            line_start: exception_line_start,
            line_end: exception_line_end,
            column_start: exception_column_start,
            column_end: exception_column_end
          })
      else
        error_response({
            message: exception.message,
            trace: exception.backtrace
          })
      end
    end

    # @param [String] method_name
    # @param [Object] params
    def self.method_response(method_name, params = nil)
      {
        result: {
          method: method_name,
          params: params
        }
      }
    end

    # @param [Object] object
    # @return [Hash]
    def self.message_response(object)
      message = object.to_s
      # TODO: method_response('message', message)

      {
        result: {
          method: 'message',
          message: message
        }
      }
    end

    
    # @param [String] method
    # @param [Hash] params
    # @return [Hash]
    def self.handler_missing_response(method, params)
      error_response({
          message: "Undefined method #{method.inspect}"
        })
    end

    # @return [Hash]
    def self.noop_response
      method_response('noop', nil)
    end

  end # Response

end # Rhubarb
