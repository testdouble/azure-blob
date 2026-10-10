# frozen_string_literal: true

require_relative "test_helper"

class TestUserDelegationKeyConfiguration < TestCase
  HOST = "https://account.blob.core.windows.net"

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
