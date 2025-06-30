# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"

class TestUserDelegationKeyExpiration < TestCase
  attr_reader :client, :key, :content

  EXPIRATION = 120

  def setup
    skip if using_shared_key
    @account_name = ENV["AZURE_ACCOUNT_NAME"]
    @container = ENV["AZURE_PRIVATE_CONTAINER"]
    @principal_id = ENV["AZURE_PRINCIPAL_ID"]
    @host = ENV["STORAGE_BLOB_HOST"]
    @client = AzureBlob::Client.new(
      account_name: @account_name,
      container: @container,
      principal_id: @principal_id,
      host: @host,
    )
    @uid = SecureRandom.uuid
    @key = "test-delegation-expiration-#{@uid}"
    @content = "Test content for delegation key expiration"
  end

  def teardown
    client.delete_blob(key) rescue AzureBlob::Http::FileNotFoundError
  end

  def test_user_delegation_key_auto_refresh_on_expiration
    original_expiration = AzureBlob::UserDelegationKey.send(:remove_const, :EXPIRATION)
    original_buffer = AzureBlob::UserDelegationKey.send(:remove_const, :EXPIRATION_BUFFER)
    AzureBlob::UserDelegationKey.const_set(:EXPIRATION, 2)
    AzureBlob::UserDelegationKey.const_set(:EXPIRATION_BUFFER, 0)

    begin
      client.create_block_blob(key, content)

      uri = client.signed_uri(
        key,
        permissions: "r",
        expiry: Time.at(Time.now.to_i + EXPIRATION).utc.iso8601,
      )

      response = AzureBlob::Http.new(uri, { "x-ms-blob-type": "BlockBlob" }).get

      assert_equal response, content

      sleep 3

      uri = client.signed_uri(
        key,
        permissions: "r",
        expiry: Time.at(Time.now.to_i + EXPIRATION).utc.iso8601,
      )

      response = AzureBlob::Http.new(uri, { "x-ms-blob-type": "BlockBlob" }).get

      assert_equal response, content
    ensure
      AzureBlob::UserDelegationKey.send(:remove_const, :EXPIRATION)
      AzureBlob::UserDelegationKey.send(:remove_const, :EXPIRATION_BUFFER)
      AzureBlob::UserDelegationKey.const_set(:EXPIRATION, original_expiration)
      AzureBlob::UserDelegationKey.const_set(:EXPIRATION_BUFFER, original_buffer)
    end
  end
end
