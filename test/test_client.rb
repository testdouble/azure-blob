# frozen_string_literal: true

require "test_helper"
require "securerandom"

  attr_reader :client, :key
class TestClient < TestCase

  def setup
    @account_name = ENV["AZURE_ACCOUNT_NAME"]
    @access_key = ENV["AZURE_ACCESS_KEY"]
    @container = ENV["AZURE_CONTAINER"]
    @client = AzureBlobStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: @container,
    )
  end

  def teardown
    client.delete_blob(key)
  end

  def test_single_upload
    @key = 'test_client#test_single_upload'
    content = "single upload content"

    client.create_block_blob(key, content)

    assert_equal content, client.get_blob(key)
  end
end
