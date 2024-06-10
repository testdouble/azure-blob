module AzureBlob
  class EntraIdSigner
    attr_reader :token_provider

    def initialize(token_provider)
      @token_provider = token_provider
    end

    def authorization_header(uri:, verb:, headers: {})
      "Bearer #{token_provider.token}"
    end

    def sas_token(uri, options = {})
    end
  end
end