# frozen_string_literal: true

require_relative "test_helper"

class TestUserDelegationKey < TestCase
  attr_reader :delegation_key, :account_name, :principal_id, :signer, :host
  def setup
    skip if using_shared_key
    @account_name = ENV["AZURE_ACCOUNT_NAME"]
    @principal_id = ENV["AZURE_PRINCIPAL_ID"]
    @host = "https://#{account_name}.blob.core.windows.net"
    @signer = AzureBlob::EntraIdSigner.new(account_name:, principal_id:, host:)
    @delegation_key = AzureBlob::UserDelegationKey.new(account_name:, signer:)
  end

  def test_do_not_refresh_under_expiration_buffer
    now = Time.now
    five_hours = 18000
    Time.stub :now,  now do
      @delegation_key = AzureBlob::UserDelegationKey.new(account_name:, signer:)
    end
      initial_expiry = @delegation_key.signed_expiry

      Time.stub :now,  now + five_hours do
        @delegation_key.refresh
      end

      assert_equal initial_expiry, @delegation_key.signed_expiry
  end

  def test_refresh_when_over_expiration_buffer
    now = Time.now
    after_expiration_buffer = now + 21601
    Time.stub :now,  now do
      @delegation_key = AzureBlob::UserDelegationKey.new(account_name:, signer:)
    end

    initial_expiry = delegation_key.signed_expiry
    Time.stub :now,  after_expiration_buffer do
      delegation_key.refresh
    end

    refute_equal initial_expiry, delegation_key.signed_expiry
  end
end
