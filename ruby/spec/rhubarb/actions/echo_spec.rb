require "rhubarb/actions/echo"

RSpec.describe Rhubarb::Actions::Echo do

  describe ".call" do
    it "returns it's argument" do
      message = {}
      response = Rhubarb::Actions::Echo.call(message)
      expect(response).to be(message)
    end
  end

end
