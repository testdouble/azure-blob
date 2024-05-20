# frozen_string_literal: true

require "test_helper"
require "securerandom"

class TestClient < TestCase
  attr_reader :client, :key, :content

  def setup
    @account_name = ENV["AZURE_ACCOUNT_NAME"]
    @access_key = ENV["AZURE_ACCESS_KEY"]
    @container = ENV["AZURE_CONTAINER"]
    @client = AzureBlobStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: @container,
    )
    @key = "test_client##{name}"
    @content = "Some random content #{Random.rand(200)}"
  end

  def teardown
    client.delete_blob(key)
  end

  def test_single_block_upload
    client.create_block_blob(key, content)

    assert_equal content, client.get_blob(key)

    client.create_block_blob(key, content)

    assert_equal content, client.get_blob(key)
  end
end
