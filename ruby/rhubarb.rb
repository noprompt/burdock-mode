require 'parser/current'
require 'unparser'
require 'logger'
require 'json'
require 'stringio'
require_relative 'rhubarb/server'
require_relative 'rhubarb/utilities'
require_relative 'rhubarb/defun_extractor'
require_relative 'rhubarb/sexp'
require_relative 'rhubarb/default_handler'

log_file = File.join([File.dirname(File.realpath(__FILE__)), "log", "rhubarb.log"])

config = {
  log_file: log_file,
  handler: Rhubarb::DefaultHandler
}

server = Rhubarb::Server.new(config)
server.start!
