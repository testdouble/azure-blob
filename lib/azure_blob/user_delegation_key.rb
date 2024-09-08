require_relative 'http'

module AzureBlob
  class UserDelegationKey # :nodoc:
    def initialize(account_name:, signer:)
      # TODO: reuse the same key if not expired
      @uri = URI.parse(
        "https://#{account_name}.blob.core.windows.net/?restype=service&comp=userdelegationkey"
      )

      @signer = signer

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

    def to_s
      user_delegation_key
    end

    attr_reader :signed_oid,
      :signed_tid,
      :signed_start,
      :signed_expiry,
      :signed_service,
      :signed_version,
      :user_delegation_key


    private
    attr_reader :uri, :user_delegation_key, :signer
  end
end
