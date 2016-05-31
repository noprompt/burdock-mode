require "burdock/ast"
require "burdock/ast/zipper"
require "burdock/ast/zipper/location"

RSpec.describe Burdock::AST::Zipper::Location do

  context "when the current location is the root" do
    let(:node) do
      Burdock::AST.from_string("1 + 2")
    end

    let(:location) do
      Burdock::AST::Zipper.from_node(node)
    end

    describe "#root?" do
      it "returns true" do
        expect(location.root?).to be(true)
      end
    end

    describe "#branch?" do
      it "returns true" do
        expect(location.branch?).to be(true)
      end
    end

    describe "#children" do
      it "returns the correct children" do
        expect(location.children).to eq(node.children)
      end
    end

    describe "#root" do
      it "is a noop" do
        expect(location.root).to be(location)
      end
    end

    describe "#up" do
      it "fails" do
        expect do
          location.up
        end.to raise_error(Burdock::AST::Zipper::ZipperError)
      end
    end

    describe "#down" do
      it "succeeds" do
        new_location = location.down
        expected_node = Burdock::AST.from_string("1")

        expect(new_location.node).to eq(expected_node)
      end
    end

    describe "#left" do
      it "returns nil" do
        expect(location.left).to be_nil
      end
    end

    describe "#right" do
      it "returns nil" do
        expect(location.right).to be_nil
      end
    end

    describe "#delete" do
      it "fails" do
        expect do
          location.delete
        end.to raise_error(Burdock::AST::Zipper::ZipperError)
      end
    end

    describe "#insert_left" do
      it "fails" do
        expect do
          location.insert_left("foo")
        end.to raise_error(Burdock::AST::Zipper::ZipperError)
      end
    end

    describe "#insert_right" do
      it "fails" do
        expect do
          location.insert_right("foo")
        end.to raise_error(Burdock::AST::Zipper::ZipperError)
      end
    end
  end

  context "when the current location is a leaf" do
    let(:node) do
      Burdock::AST.from_string("1 + 2")
    end

    let(:location) do
      Burdock::AST::Zipper.from_node(node).down.down
    end

    describe "#root?" do
      it "returns false" do
        expect(location.root?).to be(false)
      end
    end

    describe "#branch?" do
      it "returns false" do
        expect(location.branch?).to be(false)
      end
    end

    describe "#children" do
      it "fails" do
        expect do
          location.children
        end.to raise_error(Burdock::AST::Zipper::ZipperError)
      end
    end

    describe "#down" do
      it "fails" do
        expect do
          location.down
        end.to raise_error(Burdock::AST::Zipper::ZipperError)
      end
    end
  end

  context "moving down then up" do
    let(:node) do
      Burdock::AST.from_string("1 + 2")
    end

    let(:initial_location) do
      Burdock::AST::Zipper.from_node(node)
    end

    let(:final_location) do
      1000.times.reduce(initial_location) do |location, _|
        location.down.up
      end
    end

    it "is equivalent to not moving at all" do
      expect(final_location).to eq(initial_location)
    end

    it "produces a new location" do
      expect(final_location).to_not be(initial_location)
    end
  end

  context "moving down then up" do
    let(:node) do
      Burdock::AST.from_string("1 + 2")
    end

    let(:initial_location) do
      Burdock::AST::Zipper.from_node(node).down
    end

    let(:final_location) do
      1000.times.reduce(initial_location) do |location, _|
        location.up.down
      end
    end

    it "is equivalent to not moving at all" do
      expect(final_location).to eq(initial_location)
    end

    it "produces a new location" do
      expect(final_location).to_not be(initial_location)
    end
  end

  context "moving right then left" do
    let(:node) do
      Burdock::AST.from_string("1 + 2")
    end

    let(:initial_location) do
      Burdock::AST::Zipper.from_node(node).down
    end

    let(:final_location) do
      1000.times.reduce(initial_location) do |location, _|
        location.right.left
      end
    end

    it "is equivalent to not moving at all" do
      expect(final_location).to eq(initial_location)
    end

    it "produces a new location" do
      expect(final_location).to_not be(initial_location)
    end
  end

  context "moving left then right" do
    let(:node) do
      Burdock::AST.from_string("1 + 2")
    end

    let(:initial_location) do
      Burdock::AST::Zipper.from_node(node).down.right
    end

    let(:final_location) do
      1000.times.reduce(initial_location) do |location, _|
        location.left.right
      end
    end

    specify "is equivalent to not moving at all" do
      expect(final_location).to eq(initial_location)
    end

    specify "produces a new location" do
      expect(final_location).to_not be(initial_location)
    end
  end

  describe "#child_locations" do
    let(:node) do
      Burdock::AST.from_string("1 + 2")
    end

  end

  describe "#left_locations" do
    let(:node) do
      Burdock::AST.from_string("[1, 2, 3, 4]")
    end

    let(:location) do
      Burdock::AST::Zipper.from_node(node).down.rightmost
    end

    it "produces nodes in the same order as #lefts" do
      expected_lefts = location.lefts
      actual_lefts = location.left_locations.map(&:node)
      expect(actual_lefts).to eq(expected_lefts)
    end
  end

  describe "#right_locations" do
    let(:node) do
      Burdock::AST.from_string("[1, 2, 3, 4]")
    end

    let(:location) do
      Burdock::AST::Zipper.from_node(node).down
    end

    it "produces nodes in the same order as #rights" do
      expected_rights = location.rights
      actual_rights = location.right_locations.map(&:node)
      expect(actual_rights).to eq(expected_rights)
    end

  end

end
