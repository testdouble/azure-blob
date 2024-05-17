# frozen_string_literal: true

require "base64"
require "openssl"
require_relative "canonicalized_headers"
require_relative "canonicalized_resource"

module Azure::ActiveStorage
  class Signer
    def initialize(access_key:)
      @access_key = Base64.decode64(access_key)
    end

    def sign(
      uri:,
      account_name:,
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

      Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", access_key, to_sign))
    end

    private

    attr_reader :access_key
  end
end
