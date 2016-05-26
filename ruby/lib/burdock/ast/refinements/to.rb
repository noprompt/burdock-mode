require 'ast/node'

module Rhubarb
  module AST
    module Refinements
      module To

        refine ::Module do
          def to_ast
            cbase = ::Parser::AST::Node.new(:cbase, [])

            self.name.split("::").reduce(cbase) do |node, segment|
              ::Parser::AST::Node.new(:const, [node, segment.to_sym])
            end
          end
        end

      end # To
    end # Refinements
  end # AST
end # Rhubarb
