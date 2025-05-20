# frozen_string_literal: true

require "rails/service/shared_service_tests"
require "uri"

class ActiveStorage::Service::AzureBlobPublicServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service.configure(:azure_public, SERVICE_CONFIGURATIONS)

  include ActiveStorage::Service::SharedServiceTests

  setup do
    skip if offline?
    @config = SERVICE_CONFIGURATIONS[:azure_public]
  end

  test "public URL generation" do
    skip if ENV["TESTING_AZURITE"]
    url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))
    host = @config[:host] || "https://#{@config[:storage_account_name]}.blob.core.windows.net"

    assert url.start_with?("#{host}/#{@config[:container]}/#{@key}")

    response = Net::HTTP.get_response(URI(url))
    assert_equal "200", response.code
  end

  test "direct upload" do
    key          = SecureRandom.base58(24)
    data         = "Something else entirely!"
    checksum     = OpenSSL::Digest::MD5.base64digest(data)
    content_type = "text/xml"
    url          = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: content_type, content_length: data.size, checksum: checksum)

    uri = URI.parse url
    request = Net::HTTP::Put.new uri.request_uri
    request.body = data
    @service.headers_for_direct_upload(key, checksum: checksum, content_type: content_type, filename: ActiveStorage::Filename.new("test.txt")).each do |k, v|
      request.add_field k, v
    end
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.port == 443) do |http|
      http.request request
    end

    response = Net::HTTP.get_response(URI(@service.url(key)))
    assert_equal "200", response.code
    assert_equal data, response.body
  ensure
    @service.delete key
  end
end
