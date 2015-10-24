require 'yard'

module Rhubarb

  class DefaultHandler

    def initialize(session)
      @session = session
    end

    def dispatch(method_name, params)
      method_sym = method_name.to_s.downcase.gsub(/-/, '_').to_sym

      if self.respond_to?(method_sym)
        self.send(method_sym, params)
      else
        ::Rhubarb::Response.handler_missing_response(method_name, params)
      end
    end

    # @param [Hash] params
    # @return [Hash]
    def initialize_buffer(params)
      buffer_id = params.fetch('buffer-id')
      buffer_contents = params.fetch('buffer-contents')

      @session.initialize_buffer(buffer_id, buffer_contents)

      message = "#{buffer_id} initialized"

      ::Rhubarb::Response.message_response(message)
    end

    # @param [Hash] params
    # @return [Hash]
    def update_buffer(params)
      @session.update_buffer(params)
      ::Rhubarb::Response.noop_response
    end

    # @param [Hash] params
    # @return [Hash]
    def buffer_contents(params)
      buffer_id = params.fetch('buffer-id')
      buffer = @session.get_buffer(buffer_id)
      buffer_contents = buffer.contents

      {
        result: {
          buffer_id: buffer_id,
          buffer_contents: buffer_contents
        }
      }
    end

    # @param [Hash] params
    # @return [Hash]
    def defun_at_point(params)
      buffer_id = params.fetch('buffer-id')
      line_number = params.fetch('buffer-current-line')

      @session.get_buffer_ast_node(buffer_id) do |ast_node, error|
        if error
          ::Rhubarb::Response.from_exception(error)
        else
          extracted_node = ::Rhubarb::DefunExtractor.extract_defun(ast_node, line_number)

          key = [buffer_id, 'sexp']
          last_extracted_node = @session[key]

          if (extracted_node != ast_node) &&
              (extracted_node.inspect != last_extracted_node.inspect)
            @session[key] = extracted_node
            ::Rhubarb::Response.method_response('sexp', [extracted_node.inspect])
          end
        end
      end
    end

    def forward_delete(params)
      buffer_id = params.fetch('buffer-id')
      point = params.fetch('buffer-current-point')
      buffer = @session.get_buffer(buffer_id)

      @session.get_buffer_ast_node(buffer_id) do |ast_node, error|
        if error
          ::Rhubarb::Response.from_exception(error)
        else
          z = ::Rhubarb::Sexp.zipper_location_at_point(ast_node, point)
          if z && z.right
            node = z.right.node
            location = node.location
            expression = location.expression

            begin_pos = expression.begin_pos.succ
            end_pos = expression.end_pos.succ
            ::Rhubarb::Response.method_response(
              'edit-delete-region',
              {
                begin_pos: begin_pos,
                end_pos: end_pos,
                test: "foo"
              })
          end
        end
      end
    end

    def forward_kill(params)
      buffer_id = params.fetch('buffer-id')
      point = params.fetch('buffer-current-point')
      line = params.fetch('buffer-current-line')
      buffer = @session.get_buffer(buffer_id)

      @session.get_buffer_ast_node(buffer_id) do |ast_node, error|
        if error
          ::Rhubarb::Response.from_exception(error)
        elsif z = Rhubarb::Sexp.zipper_location_at_point(ast_node, point)
          rights_whom_contain_line = z.rights.select do |node|
            ::Rhubarb::Sexp.node_contains_line?(node, line)
          end

          rightmost_on_line = rights_whom_contain_line.last

          begin_node = z.node
          end_node = rightmost_on_line || begin_node

          begin_exp = begin_node.location.expression
          begin_pos = begin_exp.begin_pos
          end_exp = end_node.location.expression
          end_pos = end_exp.end_pos

          if buffer.contents[end_pos] == ','
            end_pos = end_pos.succ
          end

          ::Rhubarb::Response.method_response(
            'edit-delete-region',
            {
              begin_pos: begin_pos.succ,
              end_pos: end_pos.succ
            })
        end
      end
    end

    def structured_wrap(params)
      buffer_id = params.fetch('buffer-id')
      point = params.fetch('buffer-current-point')
      pair = params.fetch('pair')

      buffer = @session.get_buffer(buffer_id)
      left, right = pair

      @session.get_buffer_ast_node(buffer_id) do |ast_node, error|
        if error
          ::Rhubarb::Response.from_exception(error)
        elsif z = Rhubarb::Sexp.zipper_location_at_point(ast_node, point)
          expr = z.node.location.expression
          begin_pos = expr.begin_pos
          end_pos = expr.end_pos
          insertion = left + buffer.contents[begin_pos...end_pos] + right
          ::Rhubarb::Response.method_response(
            'edit-replace-region',
            {
              begin_pos: begin_pos.succ,
              end_pos: end_pos.succ,
              insertion: insertion
            })
        end
      end
    end

    def sexp_at_point(params)
      buffer_id = params.fetch('buffer-id')
      point = params.fetch('buffer-current-point')
      buffer = @session.get_buffer(buffer_id)

      @session.get_buffer_ast_node(buffer_id) do |ast_node, error|
        if error
          ::Rhubarb::Response.from_exception(error)
        else
          extracted_node = Rhubarb::Sexp.find_node_at_point(ast_node, point)

          key = [buffer_id, 'sexp']
          last_extracted_node = @session[key]

          if (extracted_node != ast_node) &&
              (extracted_node.inspect != last_extracted_node.inspect)
            @session[key] = extracted_node
            
            if extracted_node.respond_to?(:location)
              location = extracted_node.location
              expression = location.expression
              begin_pos = expression.begin_pos.succ
              end_pos = expression.end_pos.succ
              ::Rhubarb::Response.method_response(
                'sexp',
                {
                  sexps: [extracted_node.inspect],
                  begin_pos: begin_pos,
                  end_pos: end_pos
                })
            end
          end
        end
      end
    end

    # Evaluation

    def test_eval(params)
      ::Rhubarb::Response.method_response('eval', ['42'])
    end

    def eval_defun(params)
      buffer_id = params.fetch('buffer-id')
      line_number = params.fetch('buffer-current-line')
      buffer = @session.get_buffer(buffer_id)

      @session.get_buffer_ast_node(buffer_id) do |ast_node, error|
        if error
          ::Rhubarb::Response.from_exception(error)
        else
          extracted_node = ::Rhubarb::DefunExtractor.extract_defun(ast_node, line_number)
          defun = ::Unparser.unparse(extracted_node)

          location = extracted_node.location
          expression = location.expression
          end_pos = expression.end_pos

          # Respect ';'
          if buffer.contents[end_pos] == ';'
            defun = defun + ';'
          end

          ::Rhubarb::Response.method_response('eval', [defun])
        end
      end
    end

    # Miscellaneous

    def extract_yard_doc(params)
      buffer_id = params.fetch('buffer-id')
      point = params.fetch('buffer-current-point')
      buffer = @session.get_buffer(buffer_id)

      @session.get_buffer_ast_node(buffer_id) do |ast_node, error|
        if error
          ::Rhubarb::Response.from_exception(error)
        else
          found_loc = Rhubarb::Sexp.find_zipper_location(ast_node) do |zipper|
            z_node = zipper.node
            Rhubarb::Sexp.node?(z_node) &&
              Rhubarb::Sexp.node_contains_point?(z_node, point) &&
              (z_node.type == :def || z_node.type == :defs)
          end

          if found_loc
            found_node = found_loc.node
            if found_node.type == :def
              args = found_node.children[1]
            else
              args = found_node.children[2]
            end

            if args.children.any?
              docstring = args.children.reduce(YARD::Docstring.new) do |docstring, arg|
                parameter = arg.children.first
                parameter_tag = YARD::Tags::Tag.new(:param, '', ['Object'], parameter.to_s)
                docstring.add_tag(parameter_tag)
                docstring
              end

              comment = docstring.to_raw.strip.gsub(/(?<=^)/, '# ')

              def_node = found_loc.node
              def_node_location = def_node.location
              def_node_expression = def_node_location.expression
              def_node_begin_pos = def_node_expression.begin_pos

              ::Rhubarb::Response.method_response(
                'edit-insert',
                {
                  begin_pos: def_node_begin_pos.succ,
                  insertion: comment << "\n"
                })
            else
              ::Rhubarb::Response.message_response('No children')
            end
          else
            ::Rhubarb::Response.message_response('No loc')
          end
        end
      end
    end

  end # DefaultHandler

end # Rhubarb
