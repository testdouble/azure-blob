# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"

class TestUserDelegationKeyExpiration < TestCase
  attr_reader :client, :key, :content

  KeyRequestFailed = Class.new(StandardError)

  def setup
    skip if using_shared_key
    @client = build_client
    @uid = SecureRandom.uuid
    @key = "test-delegation-expiration-#{@uid}"
    @content = "Test content for delegation key expiration"
  end

  def teardown
    client.delete_blob(key) rescue AzureBlob::Http::FileNotFoundError
  end

  def test_user_delegation_key_auto_refresh_on_expiration
    # The key is refreshed once less than half of its lifetime is left, after 5 seconds.
    client = build_client(delegation_key_expiration: 10)
    client.create_block_blob(key, content)

    first_uri = signed_uri(expires_in: 2, client:)
    assert_equal content, download(first_uri)

    sleep 6

    # This URL still fits inside the first key, so only its approaching expiry can trigger the refresh.
    second_uri = signed_uri(expires_in: 2, client:)
    assert_equal content, download(second_uri)

    assert_operator sas_time(second_uri, :ske), :>, sas_time(first_uri, :ske)
  end

  def test_user_delegation_key_covers_a_signed_url_that_outlives_it
    client = build_client(delegation_key_expiration: 2)
    client.create_block_blob(key, content)

    uri = signed_uri(expires_in: 120, client:)
    assert_operator sas_time(uri, :ske), :>=, sas_time(uri, :se)

    sleep 3

    assert_equal content, download(uri)
  end

  def test_user_delegation_key_lasts_seven_hours_by_default
    uri = signed_uri(expires_in: 60, client: build_client)

    assert_in_delta Time.now + 25200, sas_time(uri, :ske), 10
  end

  def test_delegation_key_expiration_sets_the_key_lifetime
    uri = signed_uri(expires_in: 60, client: build_client(delegation_key_expiration: 86400))

    assert_in_delta Time.now + 86400, sas_time(uri, :ske), 10
  end

  def test_user_delegation_key_is_reused_while_the_signed_urls_fit_in_it
    client = build_client(delegation_key_expiration: 3600)

    first_uri = signed_uri(expires_in: 1800, client:)
    sleep 1 # a second key request would carry a later expiry
    second_uri = signed_uri(expires_in: 600, client:)

    assert_equal sas_time(first_uri, :ske), sas_time(second_uri, :ske)
  end

  def test_signed_url_can_last_seven_days_but_not_longer
    client.create_block_blob(key, content)
    seven_days = AzureBlob::UserDelegationKey::MAX_EXPIRATION

    uri = signed_uri(expires_in: seven_days)
    assert_equal sas_time(uri, :se), sas_time(uri, :ske)
    assert_equal content, download(uri)

    error = assert_raises(ArgumentError) { signed_uri(expires_in: seven_days + 60) }
    assert_match(/7 days/, error.message)
  end

  def test_a_failed_key_request_leaves_the_key_unchanged
    client = build_client(delegation_key_expiration: 3600)
    first_uri = signed_uri(expires_in: 60, client:)

    AzureBlob::Http.stub(:new, ->(*, **) { raise KeyRequestFailed }) do
      assert_raises(KeyRequestFailed) { signed_uri(expires_in: 7200, client:) }
    end

    second_uri = signed_uri(expires_in: 7200, client:)

    assert_operator sas_time(second_uri, :ske), :>, sas_time(first_uri, :ske)
    assert_in_delta Time.now + 7200, sas_time(second_uri, :ske), 10
  end

  private

  def build_client(**options)
    AzureBlob::Client.new(
      account_name: ENV["AZURE_ACCOUNT_NAME"],
      container: ENV["AZURE_PRIVATE_CONTAINER"],
      principal_id: ENV["AZURE_PRINCIPAL_ID"],
      use_managed_identities: ENV["USE_MANAGED_IDENTITIES"] == "true",
      host: ENV["STORAGE_BLOB_HOST"],
      **options,
    )
  end

  def signed_uri(expires_in:, client: self.client)
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
