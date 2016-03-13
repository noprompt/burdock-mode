require "rhubarb/actions/expression_at_point"

RSpec.describe Rhubarb::Actions::ExpressionAtPoint do

  describe ".call" do

    let(:operator) do
      %w{+ - * /}.sample
    end

    let(:left_operand) do
      %w{1 2 3 4}.sample
    end

    let(:right_operand) do
      %w{1 2 3 4}.sample
    end

    let(:arithmetic_expression) do
      "%s %s %s" % [left_operand, operator, right_operand]
    end

    it "returns a message Ruby AST node as Ruby code" do
      # Example message 1

      message_1 = {
        "params" => {
          "point" => arithmetic_expression.index(left_operand),
          "source" => arithmetic_expression
        }
      }

      response_1 = Rhubarb::Actions::ExpressionAtPoint.call(message_1)

      expected_response_pattern_1 = {
        :method => an_instance_of(String),
        :params => {
          :end_point => an_instance_of(Fixnum),
          :source => left_operand,
          :start_point => an_instance_of(Fixnum),
        }
      }

      expect(response_1).to match(expected_response_pattern_1)

      # Example message 2

      message_2 = {
        "params" => {
          "point" => arithmetic_expression.index(right_operand),
          "source" => arithmetic_expression
        }
      }

      response_2 = Rhubarb::Actions::ExpressionAtPoint.call(message_2)

      expected_response_pattern_2 = {
        :method => an_instance_of(String),
        :params => {
          :end_point => an_instance_of(Fixnum),
          :source => right_operand,
          :start_point => an_instance_of(Fixnum),
        }
      }

      expect(response_2).to match(expected_response_pattern_2)

      # Example message 3

      message_3 = {
        "params" => {
          "point" => arithmetic_expression.index(operator),
          "source" => arithmetic_expression
        }
      }

      response_3 = Rhubarb::Actions::ExpressionAtPoint.call(message_3)

      expected_response_pattern_3 = {
        :method => an_instance_of(String),
        :params => {
          :end_point => an_instance_of(Fixnum),
          :source => arithmetic_expression,
          :start_point => an_instance_of(Fixnum),
        }
      }

      expect(response_3).to match(expected_response_pattern_3)
    end
  end

end
