# frozen_string_literal: true

require "rails/test_helper"
require "rails/database/setup"


class ActiveStorage::AzureBlobDirectUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    skip if offline?
    @config = SERVICE_CONFIGURATIONS[:azure]
    ActiveStorage::Blob.service = ActiveStorage::Service.configure(:azure, SERVICE_CONFIGURATIONS)
  end

  test "creating new direct upload" do
    skip if ENV["TESTING_AZURITE"]
    checksum = OpenSSL::Digest::MD5.base64digest("Hello")
    metadata = {
      "foo" => "bar",
      "my_key_1" => "my_value_1",
      "my_key_2" => "my_value_2",
      "platform" => "my_platform",
      "library_ID" => "12345",
    }

    post rails_direct_uploads_url, params: { blob: {
      filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata, } }

    host = @config[:host] || "https://#{@config[:storage_account_name]}.blob.core.windows.net"

    response.parsed_body.tap do |details|
      assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
      assert_equal "hello.txt", details["filename"]
      assert_equal 6, details["byte_size"]
      assert_equal checksum, details["checksum"]
      assert_equal metadata, details["metadata"]
      assert_equal "text/plain", details["content_type"]
      assert details["direct_upload"]["url"].start_with?("#{host}/#{@config[:container]}")
      assert_equal({ "Content-Type" => "text/plain", "Content-MD5" => checksum, "x-ms-blob-content-disposition" => "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", "x-ms-blob-type" => "BlockBlob" }, details["direct_upload"]["headers"])
    end
  end
end
