require 'ast/node'

module Rhubarb
  module AST
    module Refinements
      module From
        refine Array do
          def ast_from
            type, *elements = self
            children = elements.map do |x|
              case x
              when Array
                x.ast_from
              else
                x
              end
            end
            ::Parser::AST::Node.new(type, children)
          end
        end
      end
    end
  end
end
