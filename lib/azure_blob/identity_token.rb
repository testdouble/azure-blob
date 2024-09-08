require "net/http"

module AzureBlob
  class IdentityToken

    RESOURCE_URI = 'https://storage.azure.com/'
    EXPIRATION_BUFFER = 600 # 10 minutes

    IDENTITY_ENDPOINT = ENV["IDENTITY_ENDPOINT"] || 'http://169.254.169.254/metadata/identity/oauth2/token'
    API_VERSION = ENV["IDENTITY_ENDPOINT"] ? '2019-08-01' : '2018-02-01'

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
      token.nil? || Time.now >= (expiration + EXPIRATION_BUFFER)
    end

    def refresh
      headers =  {'Metadata' => 'true'}
      headers['X-IDENTITY-HEADER'] = ENV['IDENTITY_HEADER'] if ENV['IDENTITY_HEADER']
      # TODO implement some retry strategies as per the documentation.
      # https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token#error-handling
      response = JSON.parse(Http.new(identity_uri, headers).get)

      @token = response['access_token']
      @expiration = Time.at(response['expires_on'].to_i)
    end

    attr_reader :identity_uri, :expiration, :token
  end
end
