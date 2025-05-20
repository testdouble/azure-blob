# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"

class TestClient < TestCase
  attr_reader :client, :key, :content

  EXPIRATION = 120

  def setup
    @account_name = ENV["AZURE_ACCOUNT_NAME"]
    @access_key = ENV["AZURE_ACCESS_KEY"]
    @container = ENV["AZURE_PRIVATE_CONTAINER"]
    @public_container = ENV["AZURE_PUBLIC_CONTAINER"]
    @principal_id = ENV["AZURE_PRINCIPAL_ID"]
    @host = ENV["STORAGE_BLOB_HOST"]
    @client = AzureBlob::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: @container,
      principal_id: @principal_id,
      host: @host,
    )
    @uid = SecureRandom.uuid
    @key = "test-client-?-#{name}-#{@uid}" # ? in key to test proper escaping
    @content = "Some random content #{Random.rand(200)}"
  end

  def teardown
    client.delete_blob(key)
  rescue AzureBlob::Http::FileNotFoundError
  end

  def test_rails_is_not_loaded
    assert_raises(NoMethodError) { 10.minutes }
  end

  def test_without_credentials
    assert_raises(AzureBlob::Error) do
      AzureBlob::Client.new(
        account_name: @account_name,
        container: @container,
      )
    end

    assert_raises(AzureBlob::Error) do
      AzureBlob::Client.new(
        access_key: "",
        account_name: @account_name,
        container: @container,
      )
    end

    AzureBlob::Client.new(
      access_key: "",
      use_managed_identities: true,
      account_name: @account_name,
      container: @container,
    )


    AzureBlob::Client.new(
      access_key: "",
      principal_id: "123",
      account_name: @account_name,
      container: @container,
    )
  end

  def test_lazy_loading_doesnt_raise_before_querying
    client = AzureBlob::Client.new(
      account_name: @account_name,
      container: @container,
      lazy: true,
    )

    assert_raises(AzureBlob::Error) do
      client.create_block_blob(key, content)
    end
  end

  def test_single_block_upload
    client.create_block_blob(key, content)

    assert_equal content, client.get_blob(key)
  end

  def test_io_upload
    client.create_block_blob(key, StringIO.new(content))

    assert_equal content, client.get_blob(key)
  end

  def test_multi_block_upload
    client.create_block_blob(key, content, block_size: 1)

    assert_equal content, client.get_blob(key)
  end

  def test_upload_integrity_blob
    checksum = OpenSSL::Digest::MD5.base64digest(content)
    client.create_block_blob(key, content, content_md5: checksum)

    assert_equal checksum, OpenSSL::Digest::MD5.base64digest(client.get_blob(key))
  end

  def test_upload_integrity_block
    checksum = OpenSSL::Digest::MD5.base64digest(content + "a") # commit blob checksum is not validated

    block_ids = content.split("", 3).map.with_index do |chunk, i|
      block_checksum = OpenSSL::Digest::MD5.base64digest(chunk)
      client.put_blob_block(key, i, chunk, content_md5: block_checksum)
    end

    client.commit_blob_blocks(key, block_ids, content_md5: checksum)

    # The checksum is not validated, but saved on the blob
    assert_equal checksum, client.get_blob_properties(key).checksum
  end

  def test_upload_raise_on_invalid_checksum_blob
    skip if ENV["TESTING_AZURITE"]
    checksum = OpenSSL::Digest::MD5.base64digest(content + "a")
    assert_raises(AzureBlob::Http::IntegrityError) { client.create_block_blob(key, content, content_md5: checksum) }
  end

  def test_upload_raise_on_invalid_checksum_block
    skip if ENV["TESTING_AZURITE"]
    checksum = OpenSSL::Digest::MD5.base64digest(content + "a")
    assert_raises(AzureBlob::Http::IntegrityError) { client.put_blob_block(key, 0, content, content_md5: checksum) }
  end

  def test_content_type_persisted
    client.create_block_blob(key, content, content_type: "funky content_type",)
    response = client.get_blob_properties(key)

    assert_equal "funky content_type", response.content_type
  end

  def test_metadata_persisted
    client.create_block_blob(key, content, metadata: { hello: "world" })
    response = client.get_blob_properties(key)

    assert_equal "world", response.metadata[:hello]
  end

  def test_disposition_persisted
    client.create_block_blob(key, content, content_disposition: "inline")
    response = client.get_blob_properties(key)
    assert_equal "inline", response.content_disposition

    client.create_block_blob(key, content, content_disposition: "attachment")
    response = client.get_blob_properties(key)
    assert_equal "attachment", response.content_disposition
  end

  def test_download
    client.create_block_blob(key, content)

    assert_equal content, client.get_blob(key)
  end

  def test_download_big
    skip
  end

  def test_download_chunk
    client.create_block_blob(key, content)

    result = client.get_blob(key, start: 0, end: 5) + client.get_blob(key, start: 6)

    assert_equal content, result
  end

  def test_download_404
    assert_raises(AzureBlob::Http::FileNotFoundError) { client.get_blob(key) }
  end

  def test_copy
    client.create_block_blob(key, content)
    assert_equal content, client.get_blob(key)

    copy_key = "#{key}_copy"

    client.copy_blob(copy_key, key)

    assert_equal content, client.get_blob(copy_key)
  end

  def test_delete
    client.create_block_blob(key, content)
    assert_equal content, client.get_blob(key)

    client.delete_blob(key)

    assert_raises(AzureBlob::Http::FileNotFoundError) { client.get_blob(key) }
  end

  def test_delete_prefix
    prefix = "#{name}_prefix_#{@uid}"
    keys = 4.times.map do |i|
      key = "#{prefix}/#{i}"
      client.create_block_blob(key, content)
      key
    end

    client.delete_prefix(prefix)

    keys.each do |key|
      assert_raises(AzureBlob::Http::FileNotFoundError) { client.get_blob(key) }
    end
  end

  def test_list_prefix
    prefix = "#{name}_prefix_#{@uid}"
    @key = "#{prefix}/#{key}"
    client.create_block_blob(key, content)

    blobs = client.list_blobs(prefix: prefix).to_a

    assert_match_content [ key ], blobs
  end

  def test_list_blobs_with_pages
    prefix = "#{name}_prefix_#{@uid}"
    keys = 4.times.map do |i|
      key = "#{prefix}/#{i}"
      client.create_block_blob(key, content)
      key
    end

    results = client.list_blobs(max_results: 2, prefix:)

    assert_match_content keys, results.to_a

    keys.each do |key|
      client.delete_blob(key)
    end
  end

  def test_get_blob_properties
    client.create_block_blob(key, content)

    blob = client.get_blob_properties(key)

    assert blob.present?
    assert_equal content.size, blob.size
  end

  def test_get_blob_properties_404
    assert_raises(AzureBlob::Http::FileNotFoundError) { client.get_blob_properties(key) }
  end

  def test_blob_exist?
    refute client.blob_exist?(key)

    client.create_block_blob(key, content)

    assert client.blob_exist?(key)
  end

  def test_append_blob
    client.create_append_blob(key)
    content.split("", 3).each { |chunk| client.append_blob_block(key, chunk) }

    assert_equal content, client.get_blob(key)
  end

  def test_put_blob_block
    block_ids = content.split("", 3).map.with_index { |chunk, i| client.put_blob_block(key, i, chunk) }

    client.commit_blob_blocks(key, block_ids)

    assert_equal content, client.get_blob(key)
  end

  def test_read_signed_uri
    client.create_block_blob(key, content)

    uri = client.signed_uri(
      key,
      permissions: "r",
      expiry: Time.at(Time.now.to_i + EXPIRATION).utc.iso8601,
    )

    response = AzureBlob::Http.new(uri, { "x-ms-blob-type": "BlockBlob" }).get

    assert_equal response, content
  end

  def test_read_only_signed_uri
    uri = client.signed_uri(
      key,
      permissions: "r",
      expiry: Time.at(Time.now.to_i + EXPIRATION).utc.iso8601,
    )
    assert_raises(AzureBlob::Http::ForbiddenError) do
      AzureBlob::Http.new(uri, { "x-ms-blob-type": "BlockBlob" }).put(content)
    end

    assert_raises(AzureBlob::Http::FileNotFoundError) { client.get_blob(key) }
  end

  def test_write_signed_uri
    client.create_block_blob(key, content)

    uri = client.signed_uri(
      key,
      permissions: "rw",
      expiry: Time.at(Time.now.to_i + EXPIRATION).utc.iso8601,
    )

    checksum = OpenSSL::Digest::MD5.base64digest(content)
    headers = {
      "Content-MD5": checksum,
      "Content-Type": "fun type",
      "x-ms-blob-content-disposition": "inline",
      "x-ms-blob-type": "BlockBlob",
    }
    AzureBlob::Http.new(uri, headers).put(content)

    properties = client.get_blob_properties(key)
    assert_equal "fun type", properties.content_type
    assert_equal "inline", properties.content_disposition
    assert_equal checksum, properties.checksum
    assert_equal content, client.get_blob(key)
  end

  def test_signed_uri_disposition_override
    client.create_block_blob(key, content, content_disposition: "attachement")

    uri = client.signed_uri(
      key,
      permissions: "r",
      expiry: Time.at(Time.now.to_i + EXPIRATION).utc.iso8601,
      content_disposition: "inline",
    )

    response = Net::HTTP.get_response(uri)
    assert_equal "inline", response["Content-Disposition"]
  end

  def test_signed_uri_type_override
    client.create_block_blob(key, content, content_type: "some type")

    uri = client.signed_uri(
      key,
      permissions: "r",
      expiry: Time.at(Time.now.to_i + EXPIRATION).utc.iso8601,
      content_type: "another type",
    )

    response = Net::HTTP.get_response(uri)
    assert_equal "another type", response["Content-Type"]
  end

  def test_get_container_properties
    skip if ENV["TESTING_AZURITE"]
    container = client.get_container_properties
    assert container.present?

    client = AzureBlob::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: "missingcontainer",
      principal_id: @principal_id,
    )
    container = client.get_container_properties
    refute container.present?
  end

  def test_container_exist?
    skip if ENV["TESTING_AZURITE"]
    assert client.container_exist?

    client = AzureBlob::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: "missingcontainer",
      principal_id: @principal_id,
    )

    refute client.container_exist?
  end

  def test_create_container
    client = AzureBlob::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: Random.alphanumeric(20).tr("0-9", "").downcase,
      principal_id: @principal_id,
      host: @host,
    )
    container = client.get_container_properties
    refute container.present?

    client.create_container
    container = client.get_container_properties
    assert container.present?

    client.delete_container
    container = client.get_container_properties
    refute container.present?
  end

  def test_get_blob_tags
    client.create_block_blob(key, content, tags: { tag1: "value 1", "tag 2": "value 2" })

    tags = client.get_blob_tags(key)

    assert_equal({ "tag1" => "value 1", "tag 2" => "value 2" }, tags)
  end

  def test_copy_between_containers
    destination_client = AzureBlob::Client.new(
      account_name: @account_name,
      access_key: @access_key,
      container: @public_container,
      principal_id: @principal_id,
      host: @host,
    )
    client.create_block_blob(key, content)
    assert_equal content, client.get_blob(key)

    destination_client.copy_blob(key, key, source_client: client)


    assert_equal content, destination_client.get_blob(key)

    begin
      destination_client.delete_blob(key)
    rescue AzureBlob::Http::FileNotFoundError
    end
  end

  def test_get_blob_additional_headers
    http_mock = Minitest::Mock.new
    http_mock.expect :get, ""

    stubbed_new = lambda do |uri, headers = {}, signer: nil, **kwargs|
      assert_equal "bar", headers[:"x-ms-foo"]
      http_mock
    end

    AzureBlob::Http.stub :new, stubbed_new do
      custom_client = AzureBlob::Client.new(account_name: "foo", access_key: "bar", container: "cont")
      custom_client.get_blob(key, headers: { foo: "bar" })
    end

    http_mock.verify
    dummy = Minitest::Mock.new
    dummy.expect :delete_blob, nil, [ key ]
    @client = dummy
  end

  def test_create_append_blob_additional_headers
    http_mock = Minitest::Mock.new
    http_mock.expect :put, true, [ nil ]

    stubbed_new = lambda do |uri, headers = {}, signer: nil, **kwargs|
      assert_equal "bar", headers[:"x-ms-foo"]
      http_mock
    end

    AzureBlob::Http.stub :new, stubbed_new do
      custom_client = AzureBlob::Client.new(account_name: "foo", access_key: "bar", container: "cont")
      custom_client.create_append_blob(key, headers: { foo: "bar" })
    end

    http_mock.verify
    dummy = Minitest::Mock.new
    dummy.expect :delete_blob, nil, [ key ]
    @client = dummy
  end
end
