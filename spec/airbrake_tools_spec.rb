require "spec_helper"

describe AirbrakeTools do
  it "has a VERSION" do
    AirbrakeTools::VERSION.should =~ /^[\.\da-z]+$/
  end
end
