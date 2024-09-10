require "json"

module AzureBlob
  class IdentityToken
    RESOURCE_URI = "https://storage.azure.com/"
    EXPIRATION_BUFFER = 600 # 10 minutes

    IDENTITY_ENDPOINT = ENV["IDENTITY_ENDPOINT"] || "http://169.254.169.254/metadata/identity/oauth2/token"
    API_VERSION = ENV["IDENTITY_ENDPOINT"] ? "2019-08-01" : "2018-02-01"

    def initialize(principal_id: nil)
      @identity_uri = URI.parse(IDENTITY_ENDPOINT)
      params = {
        'api-version': API_VERSION,
        resource: RESOURCE_URI,
      }
      params[:principal_id] = principal_id if principal_id
      @identity_uri.query = URI.encode_www_form(params)
    end

    def to_s
      refresh if expired?
      token
    end

    private

    def expired?
      token.nil? || Time.now >= (expiration - EXPIRATION_BUFFER)
    end

    def refresh
      headers =  { "Metadata" => "true" }
      headers["X-IDENTITY-HEADER"] = ENV["IDENTITY_HEADER"] if ENV["IDENTITY_HEADER"]

      attempt = 0
      begin
        attempt += 1
        response = JSON.parse(AzureBlob::Http.new(identity_uri, headers).get)
      rescue AzureBlob::Http::Error => error
        if should_retry?(error, attempt)
          attempt = 1 if error.status == 410
          delay = exponential_backoff(error, attempt)
          Kernel.sleep(delay)
          retry
        end
        raise
      end
      @token = response["access_token"]
      @expiration = Time.at(response["expires_on"].to_i)
    end

    def should_retry?(error, attempt)
      is_500 = error.status/500 == 1
      (is_500 || [ 404, 408, 410, 429 ].include?(error.status)) && attempt < 5
    end

    def exponential_backoff(error, attempt)
      EXPONENTIAL_BACKOFF[attempt -1] || raise(AzureBlob::Error.new("Exponential backoff out of bounds!"))
    end
    EXPONENTIAL_BACKOFF = [ 2, 6, 14, 30 ]

    attr_reader :identity_uri, :expiration, :token
  end
end
