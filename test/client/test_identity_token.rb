# frozen_string_literal: true

require_relative "test_helper"

class TestIdentityToken < TestCase
  attr_reader :identity_token
  def setup
    @principal_id = ENV["AZURE_PRINCIPAL_ID"]
  end

  def test_do_not_refresh_under_expiration_buffer
    http_mock = Minitest::Mock.new
    now = Time.now
    expiration = now.to_i + 3600 # Expire in 1 hour
    http_mock.expect :get, JSON.generate({access_token: '123', expires_on: expiration})

    token = nil
    new_token = nil


    AzureBlob::Http.stub :new, http_mock do
      @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
      Time.stub :now, Time.now do
        token = identity_token.to_s
      end

      http_mock.expect :get, JSON.generate({access_token: '321', expires_on: expiration})

      Time.stub :now,  Time.at(now.to_i + 1000) do
        new_token = identity_token.to_s
      end
    end

    assert_equal '123', token
    assert_equal '123', new_token
  end

  def test_refresh_when_over_expiration_buffer
    http_mock = Minitest::Mock.new
    now = Time.now
    expiration = now.to_i + 3600 # Expire in 1 hour
    http_mock.expect :get, JSON.generate({access_token: '123', expires_on: expiration})

    token = nil
    new_token = nil


    AzureBlob::Http.stub :new, http_mock do
      @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
      Time.stub :now, Time.now do
        token = identity_token.to_s
      end

      http_mock.expect :get, JSON.generate({access_token: '321', expires_on: expiration})

      Time.stub :now,  Time.at(expiration - 10) do
        new_token = identity_token.to_s
      end
    end

    assert_equal '123', token
    assert_equal '321', new_token
  end

  def test_exponential_backoff
    #https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token#error-handling
    http_mock = Minitest::Mock.new
    def http_mock.get; raise AzureBlob::Http::Error.new(status: 404) end
    slept = []
    sleep_lambda = ->(time){ slept << time}
    AzureBlob::Http.stub :new, http_mock do
      Kernel.stub :sleep, sleep_lambda do

        @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
        assert_raises(AzureBlob::Http::Error){ identity_token.to_s }
      end
    end

    assert_equal [2,6,14,30], slept
  end


  def test_410_retry
    http_mock = Minitest::Mock.new
    def http_mock.get; raise AzureBlob::Http::Error.new(status: 410) end
    attempt = 0
    slept = []
    sleep_lambda = ->(time) do
      attempt += 1
      slept << time
      if attempt > 3
        def http_mock.get; raise AzureBlob::Http::Error.new(status: 404) end
      end
    end
    AzureBlob::Http.stub :new, http_mock do
      Kernel.stub :sleep, sleep_lambda do

        @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
        assert_raises(AzureBlob::Http::Error){ identity_token.to_s }
      end
    end

    assert_equal [2, 2, 2, 2, 6, 14, 30], slept
  end
end
