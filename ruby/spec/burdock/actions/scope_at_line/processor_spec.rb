require "burdock/actions/scope_at_line/processor"
require "burdock/ast"

RSpec.describe Burdock::Actions::ScopeAtLine::Processor do

  describe "#process" do
    it "returns the expected scope" do
      example_source = <<RUBY
module Foo
  class Bar < Baz
    point :b
  
    def initialize
      @point_c
    end
  end
end
RUBY
      example_node = Burdock::AST.from_string(example_source)

      expected_node = Burdock::AST.from_string <<RUBY
module Foo
  class Bar < Baz
    point :b
  end
end
RUBY
      # 1: module Foo 
      actual_node = described_class.new(1).process(example_node)
      expect(actual_node).to eq(example_node)

      # 2:   class Bar < Baz 
      actual_node = described_class.new(1).process(example_node)
      expect(actual_node).to eq(example_node)

      # 3:     point :b
      actual_node = described_class.new(3).process(example_node)
      expect(actual_node).to eq(expected_node)

      # 4:
      actual_node = described_class.new(4).process(example_node)
      expect(actual_node).to eq(example_node)

      expected_node = Burdock::AST.from_string <<RUBY
module Foo
  class Bar < Baz
    def initialize
      @point_c
    end
  end
end
RUBY

      # 5: def initialize
      actual_node = described_class.new(5).process(example_node)
      expect(actual_node).to eq(expected_node)

      # 6:   @point_c
      actual_node = described_class.new(6).process(example_node)
      expect(actual_node).to eq(expected_node)

      # 7: end 
      actual_node = described_class.new(7).process(example_node)
      expect(actual_node).to eq(expected_node)
    end
  end # #process

end
