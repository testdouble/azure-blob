# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "azure_blob_storage"

require "minitest/autorun"
require "debug"

class TestCase < Minitest::Test
end
