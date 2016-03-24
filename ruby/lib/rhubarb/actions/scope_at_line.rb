require_relative "scope_at_line/processor"
require_relative "../ast"

module Rhubarb
  module Actions
    module ScopeAtLine
      # @param [Hash] message
      # @return [Hash]
      def self.call(message)
        params = message.fetch("params")
        line_number = params.fetch("line-number")
        source = params.fetch("source")

        processor = Rhubarb::Actions::ScopeAtLine::Processor.new(line_number)
        node = Rhubarb::AST.from_string(source)
        maybe_node = processor.process(node)

        if maybe_node
          ruby_source = Unparser.unparse(maybe_node)

          {
            method: "rhubarb/source",
            params: {
              source: ruby_source
            }
          }
        else
          {
            method: "rhubarb/source",
            params: {
              source: nil
            }
          }
        end
      end

      # @return [Array]
      def self.required_parameters
        [
          "line-number",
          "source"
        ]
      end

      module Documentation
        # @return [Hash]
        def self.call(_message)
          {
            method: "rhubarb/documentation",
            params: {
              fields: [
                {
                  description: "Ruby source code.",
                  name: "source",
                  required: true,
                  type: "string",
                },
                {
                  description: "The line number to reference.",
                  name: "line-number",
                  required: true,
                  type: "number",
                }
              ]
            }
          }
        end
      end # Documentation

    end # ScopeAtLine
  end # Actions
end # Rhubarb
