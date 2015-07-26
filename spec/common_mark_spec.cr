require "./spec_helper"

describe CommonMark do
  it "works" do
    CommonMark.to_html("").should eq("")
    CommonMark.to_html("# Header").should eq("<h1>Header</h1>")
  end
end
