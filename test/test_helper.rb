# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "azure_blob"

require "minitest/autorun"
require "debug"

class TestCase < Minitest::Test
  def assert_match_content(expected, received)
    assert_equal expected.size, received.size
    expected.each do |element|
      assert received.include?(element)
    end
  end
end
