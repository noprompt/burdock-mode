require 'stringio'
require 'parser/current'

module Rhubarb

  class Parser < ::Parser::CurrentRuby

    def self.parse(*args)
      ast_node, error = nil, nil

      new_stderr = StringIO.new
      old_stderr, $stderr = $stderr, new_stderr

      ast_node = super(*args)
    rescue ::Parser::SyntaxError => error
      raise error
    ensure
      new_stderr.close
      $stderr = old_stderr
    end

  end # Parser

end # Rhubarb
