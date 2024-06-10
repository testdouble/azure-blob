#
# As of 04/04/2018, there are 2 supported ways to get MSI Token.
#
# - Using the extension installed locally and accessing
#   http://localhost:50342/oauth2/token to get the MSI Token
# - Accessing the http://169.254.169.254/metadata/identity/oauth2/token to get
#   the MSI Token (default)
#
# Find further details here
# https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/tutorial-linux-vm-access-storage
#
# [How to use managed identities for Azure resources on an Azure VM to acquire an access token](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token)
#
# Azure Instance Metadata Service (IMDS) endpoint
# http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/

require "net/http"

#
# Class that provides access to authentication token via Managed Service
# Identity.
#
module AzureBlob
  module Auth
    class TokenProvider

      RESOURCE_URI_STORAGE = 'https://storage.azure.com/'
      API_VERSION = '2018-02-01'

      attr_reader :token
      attr_reader :token_expires_on

      attr_reader :expiration_threshold
      attr_reader :msi_identity_uri

      def initialize(msi_identity_uri:, resource_uri:, expiration_threshold: 10.minutes)
        @msi_identity_uri = URI.parse(msi_identity_uri)
        params = {
          :'api-version' => AzureBlob::Auth::TokenProvider::API_VERSION,
          :resource => resource_uri,
        }
        @msi_identity_uri.query = URI.encode_www_form(params)
        @expiration_threshold = expiration_threshold
      end

      def token_expired?
        @token.nil? || Time.now >= (@token_expires_on + expiration_threshold)
      end

      def token
        if(self.token_expired?)
          self.get_new_token()
        end
        @token
      end

      private

      def get_new_token
        # curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/' -H Metadata:true
        res = Net::HTTP.get_response(msi_identity_uri, {'Metadata' => 'true'})
        json_res = JSON.parse(res.body)

        @token = json_res['access_token']
        # The number of seconds from "1970-01-01T0:0:0Z UTC" (corresponds to the token's exp claim).
        @token_expires_on = Time.at(json_res['expires_on'].to_i)
      end
    end
  end
end

# subscription_id = ENV['AZURE_SUBSCRIPTION_ID']
# tenant_id = ENV['AZURE_TENANT_ID']
# resource_group_name = ENV['RESOURCE_GROUP_NAME']
# msi_identity_uri = ENV['MSI_IDENTITY_URI'] || 'http://169.254.169.254/metadata/identity/oauth2/token'