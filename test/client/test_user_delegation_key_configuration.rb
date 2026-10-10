# frozen_string_literal: true

require_relative "test_helper"

class TestUserDelegationKeyConfiguration < TestCase
  SIGNED_EXPIRY = "2026-09-25T12:00:00Z"
  HOST = "https://account.blob.core.windows.net"

  class FakeSigner
    def host = HOST
  end

  class FakeHttp
    attr_reader :posts

    def initialize(posts)
      @posts = posts
    end

    def post(content)
      posts << content
      <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <UserDelegationKey>
          <SignedOid>oid</SignedOid>
          <SignedTid>tid</SignedTid>
          <SignedStart>2026-09-18T12:00:00Z</SignedStart>
          <SignedExpiry>#{SIGNED_EXPIRY}</SignedExpiry>
          <SignedService>b</SignedService>
          <SignedVersion>2024-05-04</SignedVersion>
          <Value>#{Base64.strict_encode64("key")}</Value>
        </UserDelegationKey>
      XML
    end
  end

  def setup
    @posts = []
  end

  attr_reader :posts

  def with_stubbed_http
    http = FakeHttp.new(posts)
    AzureBlob::Http.stub(:new, ->(*, **) { http }) { yield }
  end

  def build_key(**options)
    with_stubbed_http do
      AzureBlob::UserDelegationKey.new(account_name: "account", signer: FakeSigner.new, **options)
    end
  end

  def requested_expiry(index = -1)
    Time.parse(posts[index][%r{<Expiry>(.*)</Expiry>}, 1])
  end

  def sign(signer, expiry)
    with_stubbed_http { signer.sas_token(URI("#{HOST}/container/blob"), permissions: "r", expiry:) }
  end

  def test_default_expiration_is_seven_hours
    now = Time.now.utc
    build_key

    assert_equal 1, posts.size
    assert_in_delta now + 25200, requested_expiry, 5
  end

  def test_custom_expiration_is_sent_in_the_request
    now = Time.now.utc
    build_key(expiration: 86400)

    assert_in_delta now + 86400, requested_expiry, 5
  end

  def test_entra_id_signer_rejects_an_invalid_expiration
    [ 0, -1, 604801, "604800" ].each do |expiration|
      assert_raises(ArgumentError) do
        AzureBlob::EntraIdSigner.new(account_name: "account", host: HOST, delegation_key_expiration: expiration)
      end
    end
  end

  def test_client_rejects_an_invalid_expiration_when_built
    error = assert_raises(ArgumentError) do
      AzureBlob::Client.new(
        account_name: "account",
        container: "container",
        principal_id: "principal",
        delegation_key_expiration: 999_999_999,
      )
    end

    assert_match(/604800/, error.message)
  end

  def test_key_is_not_requested_again_until_close_to_expiry
    key = build_key(expiration: 1800)

    with_stubbed_http { 3.times { key.to_s } }

    assert_equal 1, posts.size
  end

  def test_key_is_requested_again_when_close_to_expiry
    key = build_key(expiration: 1800)

    with_stubbed_http do
      Time.stub(:now, Time.now + 1000) { key.to_s }
    end

    assert_equal 2, posts.size
  end

  def test_key_is_extended_when_the_signed_url_outlives_it
    signer = AzureBlob::EntraIdSigner.new(account_name: "account", host: HOST, delegation_key_expiration: 3600)
    expiry = Time.at(Time.now.to_i + 7200).utc.iso8601

    sign(signer, expiry)

    assert_equal 2, posts.size
    assert_equal Time.parse(expiry), requested_expiry
  end

  def test_key_is_not_requested_again_when_the_signed_url_fits
    signer = AzureBlob::EntraIdSigner.new(account_name: "account", host: HOST, delegation_key_expiration: 3600)

    sign(signer, Time.at(Time.now.to_i + 1800).utc.iso8601)
    sign(signer, nil)

    assert_equal 1, posts.size
  end

  def test_key_is_extended_to_a_time_in_any_zone
    key = build_key(expiration: 1800)
    valid_until = Time.at(Time.now.to_i + 3600).getlocal("+02:00")

    with_stubbed_http { key.refresh(valid_until:) }

    assert_equal 2, posts.size
    assert_includes posts.last, "<Expiry>#{valid_until.getutc.iso8601}</Expiry>"
  end

  def test_signed_url_can_last_seven_days_but_not_longer
    client = AzureBlob::Client.new(account_name: "account", container: "container", principal_id: "principal")
    now = Time.utc(2026, 10, 10, 12)

    Time.stub(:now, now) do
      with_stubbed_http { client.signed_uri("blob", permissions: "r", expiry: (now + 604800).iso8601) }

      assert_equal 2, posts.size
      assert_equal now + 604800, requested_expiry

      error = assert_raises(ArgumentError) do
        with_stubbed_http { client.signed_uri("blob", permissions: "r", expiry: (now + 604801).iso8601) }
      end
      assert_match(/7 days/, error.message)
    end

    assert_equal 2, posts.size
  end

  def test_entra_id_signer_forwards_the_expiration
    signer = AzureBlob::EntraIdSigner.new(account_name: "account", host: HOST, delegation_key_expiration: 3600)

    now = Time.now.utc
    with_stubbed_http { signer.send(:delegation_key) }

    assert_in_delta now + 3600, requested_expiry, 5
  end

  def test_entra_id_signer_defaults_to_seven_hours
    signer = AzureBlob::EntraIdSigner.new(account_name: "account", host: HOST)

    now = Time.now.utc
    with_stubbed_http { signer.send(:delegation_key) }

    assert_in_delta now + 25200, requested_expiry, 5
  end

  def test_client_passes_the_expiration_to_the_entra_id_signer
    client = AzureBlob::Client.new(
      account_name: "account",
      container: "container",
      principal_id: "principal",
      delegation_key_expiration: 172800,
      lazy: true,
    )

    now = Time.now.utc
    with_stubbed_http { client.send(:signer).send(:delegation_key) }

    assert_in_delta now + 172800, requested_expiry, 5
  end

  def test_client_does_not_pass_the_expiration_to_the_shared_key_signer
    client = AzureBlob::Client.new(
      account_name: "account",
      access_key: Base64.strict_encode64("access-key"),
      container: "container",
      delegation_key_expiration: 172800,
    )

    assert_instance_of AzureBlob::SharedKeySigner, client.send(:signer)
  end
end
