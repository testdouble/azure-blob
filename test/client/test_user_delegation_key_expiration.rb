# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"

class TestUserDelegationKeyExpiration < TestCase
  attr_reader :client, :key, :content

  # The key is refreshed when it has less than half of its lifetime left (1 second).
  DELEGATION_KEY_EXPIRATION = 2

  def setup
    skip if using_shared_key
    @account_name = ENV["AZURE_ACCOUNT_NAME"]
    @container = ENV["AZURE_PRIVATE_CONTAINER"]
    @principal_id = ENV["AZURE_PRINCIPAL_ID"]
    @use_managed_identities = ENV["USE_MANAGED_IDENTITIES"] == "true"
    @host = ENV["STORAGE_BLOB_HOST"]
    @client = AzureBlob::Client.new(
      account_name: @account_name,
      container: @container,
      principal_id: @principal_id,
      use_managed_identities: @use_managed_identities,
      host: @host,
      delegation_key_expiration: DELEGATION_KEY_EXPIRATION,
    )
    @uid = SecureRandom.uuid
    @key = "test-delegation-expiration-#{@uid}"
    @content = "Test content for delegation key expiration"
  end

  def teardown
    client.delete_blob(key) rescue AzureBlob::Http::FileNotFoundError
  end

  def test_user_delegation_key_auto_refresh_on_expiration
    client.create_block_blob(key, content)

    first_uri = signed_uri(expires_in: DELEGATION_KEY_EXPIRATION)
    assert_equal content, download(first_uri)

    sleep 3

    second_uri = signed_uri(expires_in: DELEGATION_KEY_EXPIRATION)
    assert_equal content, download(second_uri)

    assert_operator sas_time(second_uri, :ske), :>, sas_time(first_uri, :ske)
  end

  def test_user_delegation_key_covers_a_signed_url_that_outlives_it
    client.create_block_blob(key, content)

    uri = signed_uri(expires_in: 120)
    assert_operator sas_time(uri, :ske), :>=, sas_time(uri, :se)

    sleep DELEGATION_KEY_EXPIRATION + 1

    assert_equal content, download(uri)
  end

  private

  def signed_uri(expires_in:)
    client.signed_uri(
      key,
      permissions: "r",
      expiry: Time.at(Time.now.to_i + expires_in).utc.iso8601,
    )
  end

  def download(uri)
    AzureBlob::Http.new(uri, { "x-ms-blob-type": "BlockBlob" }).get
  end

  def sas_time(uri, field)
    Time.parse(URI.decode_www_form(uri.query).to_h.fetch(field.to_s))
  end
end
