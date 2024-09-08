require "base64"
require "openssl"
require "net/http"
require "rexml/document"

require_relative "canonicalized_resource"
require_relative "msi_token_provider"

module AzureBlob
  class EntraIdSigner # :nodoc:
    attr_reader :token_provider
    attr_reader :account_name

    def initialize(account_name:, principal_id: nil)
      @token_provider = AzureBlob::MsiTokenProvider.new(principal_id:)
      @account_name = account_name
    end

    def authorization_header(uri:, verb:, headers: {})
      "Bearer #{token_provider.token}"
    end

    def sas_token(uri, options = {})
      # 1. Acquire an OAuth 2.0 token from Microsoft Entra ID.
      # 2. Use the token to request the user delegation key by calling the Get User Delegation Key operation.

      # TODO: move the user delegation key handling into it's own
      # UserDelegationKeyProvider and reuse the same key if not expired
      user_delegation_key_uri = URI.parse(
        "https://#{account_name}.blob.core.windows.net/?restype=service&comp=userdelegationkey"
      )
      now = Time.now.utc

      key_start = now.iso8601
      key_expiry = (now + 7.hours).iso8601

      content = <<-XML.squish
        <?xml version="1.0" encoding="utf-8"?>
        <KeyInfo>
            <Start>#{key_start}</Start>
            <Expiry>#{key_expiry}</Expiry>
        </KeyInfo>
      XML
      http = AzureBlob::Http.new(user_delegation_key_uri, signer: self)
      response = http.post(content)

      # 3. Use the user delegation key to construct the SAS token with the appropriate fields.
      doc = REXML::Document.new(response)
      # <?xml version="1.0" encoding="utf-8"?>
      # <UserDelegationKey>
      #     <SignedOid>String containing a GUID value</SignedOid>
      #     <SignedTid>String containing a GUID value</SignedTid>
      #     <SignedStart>String formatted as ISO date</SignedStart>
      #     <SignedExpiry>String formatted as ISO date</SignedExpiry>
      #     <SignedService>b</SignedService>
      #     <SignedVersion>String specifying REST api version to use to create the user delegation key</SignedVersion>
      #     <Value>String containing the user delegation key</Value>
      # </UserDelegationKey>
      signed_oid  = doc.get_elements("/UserDelegationKey/SignedOid").first.get_text.to_s
      signed_tid = doc.get_elements("/UserDelegationKey/SignedTid").first.get_text.to_s
      signed_start = doc.get_elements("/UserDelegationKey/SignedStart").first.get_text.to_s
      signed_expiry = doc.get_elements("/UserDelegationKey/SignedExpiry").first.get_text.to_s
      signed_service = doc.get_elements("/UserDelegationKey/SignedService").first.get_text.to_s
      signed_version = doc.get_elements("/UserDelegationKey/SignedVersion").first.get_text.to_s
      user_delegation_key = Base64.decode64(doc.get_elements("/UserDelegationKey/Value").first.get_text.to_s)

      # :start and :expiry, if present, are already in iso8601 format
      start = options[:start] || now.iso8601
      expiry = options[:expiry] ||  (now + 5.minutes).iso8601

      canonicalized_resource = CanonicalizedResource.new(uri, account_name, url_safe: false, service_name: :blob)
      to_sign = [
        options[:permissions],         # signedPermissions + "\n" +
        start,                         # signedStart + "\n" +
        expiry,                        # signedExpiry + "\n" +
        canonicalized_resource,        # canonicalizedResource + "\n" +
        signed_oid,                    # signedKeyObjectId + "\n" +
        signed_tid,                    # signedKeyTenantId + "\n" +
        signed_start,                  # signedKeyStart + "\n" +
        signed_expiry,                 # signedKeyExpiry  + "\n" +
        signed_service,                # signedKeyService + "\n" +
        signed_version,                # signedKeyVersion + "\n" +
        nil,                           # signedAuthorizedUserObjectId + "\n" +
        nil,                           # signedUnauthorizedUserObjectId + "\n" +
        nil,                           # signedCorrelationId + "\n" +
        options[:ip],                  # signedIP + "\n" +
        options[:protocol],            # signedProtocol + "\n" +
        SAS::Version,                  # signedVersion + "\n" +
        SAS::Resources::Blob,          # signedResource + "\n" +
        nil,                           # signedSnapshotTime + "\n" +
        nil,                           # signedEncryptionScope + "\n" +
        nil,                           # rscc + "\n" +
        options[:content_disposition], # rscd + "\n" +
        nil,                           # rsce + "\n" +
        nil,                           # rscl + "\n" +
        options[:content_type],        # rsct
      ].join("\n")

      query = {
        SAS::Fields::Permissions => options[:permissions],
        SAS::Fields::Start => start,
        SAS::Fields::Expiry => expiry,

        SAS::Fields::SignedObjectId => signed_oid,
        SAS::Fields::SignedTenantId => signed_tid,
        SAS::Fields::SignedKeyStartTime => signed_start,
        SAS::Fields::SignedKeyExpiryTime => signed_expiry,
        SAS::Fields::SignedKeyService => signed_service,
        SAS::Fields::Signedkeyversion => signed_version,


        SAS::Fields::SignedIp => options[:ip],
        SAS::Fields::SignedProtocol => options[:protocol],
        SAS::Fields::Version => SAS::Version,
        SAS::Fields::Resource => SAS::Resources::Blob,

        SAS::Fields::Disposition => options[:content_disposition],
        SAS::Fields::Type => options[:content_type],
        SAS::Fields::Signature => sign(to_sign, key: user_delegation_key),

      }.reject { |_, value| value.nil? }

      URI.encode_www_form(**query)
    end

    private

    def sign(body, key:)
      Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", key, body))
    end

    module SAS # :nodoc:
      Version = "2024-05-04"
      module Fields # :nodoc:
        Permissions = :sp
        Version = :sv
        Start = :st
        Expiry = :se
        Resource = :sr
        Signature = :sig
        Disposition = :rscd
        Type = :rsct
        SignedObjectId = :skoid
        SignedTenantId = :sktid
        SignedKeyStartTime = :skt
        SignedKeyExpiryTime = :ske
        SignedKeyService = :sks
        Signedkeyversion = :skv
        SignedIp = :sip
        SignedProtocol = :spr
      end
      module Resources # :nodoc:
        Blob = :b
      end
    end
  end
end
