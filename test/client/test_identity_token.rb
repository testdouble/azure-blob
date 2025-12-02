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
    expect_http_method(http_mock, "123", expiration)

    token = nil
    new_token = nil

    AzureBlob::Http.stub :new, http_mock do
      @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
      Time.stub :now, Time.now do
        token = identity_token.to_s
      end

      expect_http_method(http_mock, "321", expiration)

      Time.stub :now,  Time.at(now.to_i + 1000) do
        new_token = identity_token.to_s
      end
    end

    assert_equal "123", token
    assert_equal "123", new_token
  end

  def test_refresh_when_over_expiration_buffer
    http_mock = Minitest::Mock.new
    now = Time.now
    expiration = now.to_i + 3600 # Expire in 1 hour
    expect_http_method(http_mock, "123", expiration)

    token = nil
    new_token = nil

    AzureBlob::Http.stub :new, http_mock do
      @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
      Time.stub :now, Time.now do
        token = identity_token.to_s
      end

      expect_http_method(http_mock, "321", expiration)

      Time.stub :now,  Time.at(expiration - 10) do
        new_token = identity_token.to_s
      end
    end

    assert_equal "123", token
    assert_equal "321", new_token
  end

  def test_exponential_backoff
    # https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token#error-handling
    http_mock = create_error_mock(404)
    slept = []
    sleep_lambda = ->(time) { slept << time }
    AzureBlob::Http.stub :new, http_mock do
      Kernel.stub :sleep, sleep_lambda do
        @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
        assert_raises(AzureBlob::Http::Error) { identity_token.to_s }
      end
    end

    assert_equal [ 2, 6, 14, 30 ], slept
  end


  def test_410_retry
    http_mock = create_error_mock(410)
    attempt = 0
    slept = []
    sleep_lambda = ->(time) do
      attempt += 1
      slept << time
      http_mock.status = 404 if attempt > 3
    end
    AzureBlob::Http.stub :new, http_mock do
      Kernel.stub :sleep, sleep_lambda do
        @identity_token = AzureBlob::IdentityToken.new(principal_id: @principal_id)
        assert_raises(AzureBlob::Http::Error) { identity_token.to_s }
      end
    end

    assert_equal [ 2, 2, 2, 2, 6, 14, 30 ], slept
  end

  private

  def expect_http_method(mock, access_token, expires_on)
    if AzureBlob::WorkloadIdentity.federated_token?
      expires_in = expires_on - Time.now.to_i
      mock.expect :post, JSON.generate({ access_token: access_token, expires_in: expires_in }), [ String ]
    else
      mock.expect :get, JSON.generate({ access_token: access_token, expires_on: expires_on.to_s })
    end
  end

  def create_error_mock(status)
    mock = Object.new
    mock.instance_variable_set(:@status, status)
    def mock.status=(s); @status = s; end
    def mock.get; raise AzureBlob::Http::Error.new(status: @status); end
    def mock.post(_); raise AzureBlob::Http::Error.new(status: @status); end
    mock
  end
end
