begin
  require "stringio"
  # Silence warnings produced by the parser gem upon load.
  old_stderr, $stderr = $stderr, StringIO.new
  require "parser"
ensure
  $stderr = old_stderr
end

module Burdock
  Parser = ::Parser
end
