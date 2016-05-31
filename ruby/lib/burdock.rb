$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), "../lib")))

require "burdock/ast"
require "burdock/actions"
require "burdock/repl"
require "burdock/environment"
require "burdock/parser"
require "burdock/unparser"

module Burdock
end
