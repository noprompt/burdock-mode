require "burdock/result"

RSpec.describe Burdock::Result do

  describe ".try" do

    let (:failure) { Burdock::Result.try { fail } }

    context "when a StandardError is thrown in the block" do

      it "returns an instance of Burdock::Result::Failure" do
        expect(failure).to be_a(Burdock::Result::Failure)
      end
      
      it "#value returns the error" do
        expect(failure.value).to be_a(StandardError)
      end

      it "#then does not change the return result of #value" do
        10_000.times.reduce(failure.then { rand }) do |result, _|
          expect(result.value).to be(failure.value)
          new_result = result.then { rand }
        end
      end

      it "#otherwise changes the return result of #value" do
        otherwise_value = double("value")
        res = failure.otherwise { otherwise_value }

        expect(failure.value).to_not be(otherwise_value)
        expect(res.value).to be(otherwise_value)
      end

      it "#otherwise is idempotent" do
        new_result = failure.otherwise { rand }
        10_000.times.reduce(new_result) do |result, _|
          expect(result.value).to be(new_result.value)
          new_result = result.otherwise { rand }
        end
      end

    end
  end
end
