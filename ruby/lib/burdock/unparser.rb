begin
  require "stringio"
  # Silence warnings produced by the parser gem upon load.
  old_stderr, $stderr = $stderr, StringIO.new
  require "unparser"
ensure
  $stderr = old_stderr
end

module Burdock
  Unparser = ::Unparser
end
