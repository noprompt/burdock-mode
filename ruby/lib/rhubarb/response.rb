require "parser"

module Rhubarb
  class Response
    
    # @param [Hash] exception
    # @return [Hash] 
    def self.from_exception(exception)
      case exception
      when ::Parser::SyntaxError
        diagnostic = exception.diagnostic
        exception_location = diagnostic.location
        exception_line_start = exception_location.line
        exception_line_end = exception_location.last_line
        exception_column_start = exception_location.column
        exception_column_end = exception_location.last_column

        error_data = {
          column_end: exception_column_end,
          column_start: exception_column_start,
          line_end: exception_line_end,
          line_start: exception_line_start,
          message: exception.message,
          trace: exception.backtrace,
        }

        error_response(error_data)

      when StandardError
        error_data = {
          message: exception.message,
          trace: exception.backtrace
        }

        error_response(error_data)
      end
    end

    # @param [Hash] 
    # @return [Hash] 
    def self.error_response(hash)
      {
        error: hash
      }
    end

  end # Response
end # Rhubarb
