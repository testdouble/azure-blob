# frozen_string_literal: true

require "test_helper"
require "securerandom"

class Azure::TestClient < Minitest::Test
  def setup
    @account_name = ENV["AZURE_ACCOUNT_NAME"]
    @access_key = ENV["AZURE_ACCESS_KEY"]
  end

  def test_upload
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "random name"
    data = "hello world!"

    pp "end_result:", client.create_block_blob("dev", key, StringIO.new(data), max_block_size: 1, metadata: {:lol => 123, "no" => :qwe})
  end

  def test_upload_prefix
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "some prefix/inside the prefix #{Random.rand(20)}"
    data = "hello world!"

    pp "end_result:", client.create_block_blob("dev", key, StringIO.new(data), max_block_size: 1, metadata: {:lol => 123, "no" => :qwe})
  end


  def test_upload_multiple
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "multiple"
    data = "hello world!"

    pp "end_result:", client.create_block_blob("dev", key, StringIO.new(data), max_block_size: 6, metadata: {:lol => 123, "no" => :qwe}, content_type: "lol", content_disposition: "inline")
  end

  def test_upload
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "random name"
    data = "hello world!"

    pp "end_result:", client.create_block_blob("dev", key, StringIO.new(data))
  end

  def test_download
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "random name"
    data = "hello world!"

    pp "end_result:", client.get_blob("dev", key)
  end

  def test_download_chunk
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "random name"
    data = "hello world!"

    pp "end_result:", client.get_blob("dev", key, start_range: 0, end_range: 3)
  end

  def test_download_chunk_endless
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "random name"
    data = "hello world!"

    pp "end_result:", client.get_blob("dev", key, start_range: 3)
  end

  def test_delete
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "random name"

    pp "end_result:", client.delete_blob("dev", key)
  end

  def test_list_blobs_prefix
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )

    pp "end_result:", client.list_blobs("dev", prefix: 'some prefix/')
  end

  def test_list_blobs_root
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )

    pp "end_result:", client.list_blobs("dev")
  end

  def test_list_blobs_pages
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )

    marker = nil
    blobs = []
    loop do
      results = client.list_blobs("dev", max_results: 2, marker:)
      blobs += results.to_a
      break unless marker = results.marker
    end
    pp "end_results:", blobs
  end

  def test_delete_prefixed
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    prefix = 'some prefix/'
    marker = nil
    loop do
      results = client.list_blobs("dev", max_results: 1, marker:, prefix:)
      results.each {|blob| client.delete_blob("dev", blob)}
      break unless marker = results.marker
    end
  end

  def test_get_blob_properties
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    key = "random name"

    response = client.get_blob_properties("dev", key)
    pp "end_result:", response.present?, response.content_length
    response = client.get_blob_properties("dev", "incorect file")
    pp "end_result:", response.present?, response.content_length
  end

  def test_url_for_direct_upload
    client = Azure::ActiveStorage::Client.new(
      account_name: @account_name,
      access_key: @access_key
    )
    pp 'results:', client.signed_uri(
      client.generate_uri("dev/direct_upload"),
      service: "b",
      permissions: "rw",
      expiry: Time.at(Time.now.to_i + 3600).utc.iso8601
    ).to_s
  end

  def test_private_url

  end
end
