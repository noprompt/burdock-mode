require "burdock/ast"
require "burdock/ast/zipper"

RSpec.describe Burdock::AST::Zipper do

  describe ".from_node" do
    context "with a valid argument" do
      it "returns a zipper location at the root of the AST::Node" do
        node = Burdock::AST.from_string("1 + 2")
        location = Burdock::AST::Zipper.from_node(node)

        expect(location).to be_a(Burdock::AST::Zipper::Location)
        expect(location.root?).to be(true)
      end
    end

    context "with an invalid argument" do
      it "fails" do
        expect {
          Burdock::AST::Zipper.from_node(1)
        }.to raise_error(ArgumentError)
      end
    end
  end

end
