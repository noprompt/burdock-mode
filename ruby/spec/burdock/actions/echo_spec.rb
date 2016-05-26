require "burdock/actions/echo"

RSpec.describe Burdock::Actions::Echo do

  describe ".call" do
    it "returns it's argument" do
      message = {}
      response = Burdock::Actions::Echo.call(message)
      expect(response).to be(message)
    end
  end

end
