# frozen_string_literal: true

require "base64"
require "openssl"
require_relative "canonicalized_headers"
require_relative "canonicalized_resource"

module AzureBlobStorage
  class Signer
    def initialize(account_name:, access_key:)
      @account_name = account_name
      @access_key = Base64.decode64(access_key)
    end

    def authorization_header(
      uri:,
      verb:,
      content_length: nil,
      content_encoding: nil,
      content_language: nil,
      content_md5: nil,
      content_type: nil,
      date: nil,
      if_modified_since: nil,
      if_match: nil,
      if_none_match: nil,
      if_unmodified_since: nil,
      range: nil,
      headers: {}
    )
      canonicalized_headers = CanonicalizedHeaders.new(headers)
      canonicalized_resource = CanonicalizedResource.new(uri, account_name)
      content_length = nil if content_length == 0
      to_sign = [
        verb,
        content_encoding,
        content_language,
        content_length,
        content_md5,
        content_type,
        date,
        if_modified_since,
        if_match,
        if_none_match,
        if_unmodified_since,
        range,
        canonicalized_headers,
        canonicalized_resource
      ].join("\n")

      "SharedKey #{account_name}:#{sign(to_sign)}"
    end

    def sas_token(uri, options)
      to_sign = [
        options[:permissions],
        options[:start],
        options[:expiry],
        CanonicalizedResource.new(uri, account_name, service_name: :blob),
        options[:identifier],
        options[:ip],
        options[:protocol],
        SAS::Version,
        SAS::Resources::Blob,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
      ].join("\n")

      URI.encode_www_form(
        SAS::Fields::Permissions => options[:permissions],
        SAS::Fields::Version => SAS::Version,
        SAS::Fields::Expiry => options[:expiry],
        SAS::Fields::Resource => SAS::Resources::Blob,
        SAS::Fields::Signature => sign(to_sign)
      )
    end

    def sign(body)
      Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", access_key, body))
    end

    private

    module SAS
      Version = '2024-05-04'
      module Fields
        Permissions = :sp
        Version = :sv
        Expiry = :se
        Resource = :sr
        Signature = :sig
      end
      module Resources
        Blob = :b
      end
    end


    attr_reader :access_key, :account_name
  end
end
