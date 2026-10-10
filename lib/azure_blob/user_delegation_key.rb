require "time"

require_relative "http"

module AzureBlob
  class UserDelegationKey # :nodoc:
    EXPIRATION = 25200 # 7 hours
    MAX_EXPIRATION = 604800 # 7 days
    EXPIRATION_BUFFER = 3600 # 1 hours
    def initialize(account_name:, signer:, expiration: EXPIRATION)
      raise ArgumentError, "expiration must be a positive number of seconds" unless expiration.is_a?(Numeric) && expiration > 0
      raise ArgumentError, "expiration cannot be greater than #{MAX_EXPIRATION} seconds (7 days)" if expiration > MAX_EXPIRATION

      @uri = URI.parse(
        "#{signer.host}/?restype=service&comp=userdelegationkey"
      )

      @signer = signer
      @expiration_duration = expiration

      refresh
    end

    def to_s
      refresh
      user_delegation_key
    end

    # Requests a new key when this one is about to expire, or when it expires
    # before +valid_until+ (the expiry of the SAS about to be signed with it).
    def refresh(valid_until: nil)
      valid_until = Time.parse(valid_until) if valid_until.is_a?(String)
      now = Time.now.utc

      if valid_until && valid_until > now + MAX_EXPIRATION
        raise ArgumentError, "signed URL expiry #{valid_until.getutc.iso8601} is more than #{MAX_EXPIRATION} seconds (7 days) away, " \
          "Azure cannot sign a user delegation SAS that lasts longer than 7 days"
      end

      return unless expired? || (valid_until && valid_until > expiration)

      start = now.iso8601
      @expiration = [ now + expiration_duration, valid_until ].compact.max
      expiry = @expiration.getutc.iso8601

      content = <<-XML.gsub!(/[[:space:]]+/, " ").strip!
        <?xml version="1.0" encoding="utf-8"?>
        <KeyInfo>
            <Start>#{start}</Start>
            <Expiry>#{expiry}</Expiry>
        </KeyInfo>
      XML

      response  = Http.new(uri, signer:).post(content)

      doc = REXML::Document.new(response)

      @signed_oid  = doc.get_elements("/UserDelegationKey/SignedOid").first.get_text.to_s
      @signed_tid = doc.get_elements("/UserDelegationKey/SignedTid").first.get_text.to_s
      @signed_start = doc.get_elements("/UserDelegationKey/SignedStart").first.get_text.to_s
      @signed_expiry = doc.get_elements("/UserDelegationKey/SignedExpiry").first.get_text.to_s
      @signed_service = doc.get_elements("/UserDelegationKey/SignedService").first.get_text.to_s
      @signed_version = doc.get_elements("/UserDelegationKey/SignedVersion").first.get_text.to_s
      @user_delegation_key = Base64.decode64(doc.get_elements("/UserDelegationKey/Value").first.get_text.to_s)
    end

    attr_reader :signed_oid,
      :signed_tid,
      :signed_start,
      :signed_expiry,
      :signed_service,
      :signed_version,
      :user_delegation_key

    private

    def expired?
      expiration.nil? || Time.now >= (expiration - refresh_buffer)
    end

    def refresh_buffer
      [ EXPIRATION_BUFFER, expiration_duration / 2 ].min
    end

    attr_reader :uri, :user_delegation_key, :signer, :expiration, :expiration_duration
  end
end
