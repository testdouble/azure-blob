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
  end


  def test_multi_block_upload
    client.create_block_blob(key, content, block_size: 1)

    assert_equal content, client.get_blob(key)
  end

  def test_download
    client.create_block_blob(key, content)

    assert_equal content, client.get_blob(key)
  end

  def test_download_chunk
    client.create_block_blob(key, content)

    result = client.get_blob(key, start: 0, end: 5) + client.get_blob(key, start: 6)

    assert_equal content, result
  end

  def test_404
    assert_raises(AzureBlobStorage::FileNotFoundError) { client.get_blob(key) }
  end
end
