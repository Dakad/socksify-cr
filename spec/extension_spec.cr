require "spec"
require "../src/lib/extension"

describe "Array" do

  it ".pack_to_C should pack 8-bit unsigned" do
    packs = [
      [97, 122, 101],
      [97, 90, 101],
      [115, 105, 109, 112, 108, 101],
      [49, 50, 51, 52, 53],
      [99, 97, 102, 195, 169]
    ]
    expected =  ["aze", "aZe", "simple", "12345", "café"]

    packs.each_with_index do |n, i|
      Array.pack_to_C(n).should eq expected[i]
    end
  end

  it ".pack_to_c should pack 8-bit signed" do
    packs = [
      [97, 122, 101],
      [97, 90, 101],
      [115, 105, 109, 112, 108, 101],
      [99, 97, 102, -61, -87],
      [68, -61, -87, 106, -61, -96, 32, 118, 117],
      [97, -62, -78, 98]
    ]
    expected =  [ "aze", "aZe", "simple", "café", "Déjà vu", "a²b"]

    packs.each_with_index do |n, i|
      Array.pack_to_c(n).should eq expected[i]
    end
  end

  it ".pack_to_N should pack 32-bit unsigned big-endian format " do
    packs = [
      [2003792484],
      [1667327683],
      [2036690028, 1864398703, 1919171113]
    ]
    expected = ["word", "caf\xC3", "yello word:)"]
    packs.each_with_index do |n,i|
      Array.pack_to_N(n).should eq expected[i]
    end
  end

  it ".pack_to_n should pack 16-bit unsigned big-endian format " do
    packs = [
      [30575, 29284],
      [25441, 26307],
      [31077, 27756, 28448, 30575, 29284, 14889]
    ]
    expected = ["word", "caf\xC3", "yello word:)"]
    packs.each_with_index do |n,i|
      Array.pack_to_n(n).should eq expected[i]
    end
  end

  it "should pack by directive format", focus: true do
    args = [
      {[65, 66, 67], "C*", "ABC"}
    ]

    args.each do |numbers, format, expected|
      actual = numbers.pack(format)
      actual.should be_a String
      actual.should eq expected
    end
  end

  it "should thrown an Exception for unsupported directive formats" do
    expect_raises RuntimeError do
      invalid_format = [ "" ]
    end
  end

end

