require_relative "scope_at_line/processor"
require_relative "../ast"

module Rhubarb
  module Actions
    module ScopeAtLine
      # @param [Hash] message
      # @return [Hash]
      def self.call(message)
        params = message.fetch(:params)
        line_number = params.fetch(:line_number)
        source = params.fetch(:source)

        processor = Rhubarb::Actions::ScopeAtLine::Processor.new(line_number)
        node = Rhubarb::AST.from_string(source)
        maybe_node = processor.process(node)

        if maybe_node
          ruby_source = Unparser.unparse(maybe_node)

          {
            method: "rhubarb.source",
            params: {
              source: ruby_source
            }
          }
        else
          {
            method: "rhubarb.source",
            params: {
              source: nil
            }
          }
        end
      end

      # @return [Array]
      def self.required_parameters
        [
          :line_number,
          :source
        ]
      end

      # @return [Hash]
      def self.documentations
        {
          method: "rhubarb.scope-at-line.documentation",
          params: {
            fields: [
              {
                description: "Ruby source code.",
                name: "source",
                type: "string",
              },
              {
                description: "The line number to reference.",
                name: "line-number",
                type: "number",
              }
            ]
          }
        }
      end
    end # ScopeAtLine
  end # Actions
end # Rhubarb
