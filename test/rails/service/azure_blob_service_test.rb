# frozen_string_literal: true

require "rails/service/shared_service_tests"
require "uri"

class ActiveStorage::Service::AzureBlobServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service.configure(:azure, SERVICE_CONFIGURATIONS)

  include ActiveStorage::Service::SharedServiceTests

  test "direct upload with content type" do
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

    assert_equal(content_type, @service.client.get_blob_properties(key).content_type)
  ensure
    @service.delete key
  end

  test "direct upload with content disposition" do
    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = OpenSSL::Digest::MD5.base64digest(data)
    url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

    uri = URI.parse url
    request = Net::HTTP::Put.new uri.request_uri
    request.body = data
    @service.headers_for_direct_upload(key, checksum: checksum, content_type: "text/plain", filename: ActiveStorage::Filename.new("test.txt"), disposition: :attachment).each do |k, v|
      request.add_field k, v
    end
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.port == 443) do |http|
      http.request request
    end

    assert_equal("attachment; filename=\"test.txt\"; filename*=UTF-8''test.txt", @service.client.get_blob_properties(key).content_disposition)
  ensure
    @service.delete key
  end

  test "upload with content_type" do
    key      = SecureRandom.base58(24)
    data     = "Foobar"

    @service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data), filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")

    url = @service.url(key, expires_in: 2.minutes, disposition: :attachment, content_type: nil, filename: ActiveStorage::Filename.new("test.html"))
    response = Net::HTTP.get_response(URI(url))
    assert_equal "text/plain", response.content_type
    assert_match(/attachment;.*test\.html/, response["Content-Disposition"])
  ensure
    @service.delete key
  end

  test "upload with content disposition" do
    key  = SecureRandom.base58(24)
    data = "Foobar"

    @service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data), filename: ActiveStorage::Filename.new("test.txt"), disposition: :inline)

    assert_equal("inline; filename=\"test.txt\"; filename*=UTF-8''test.txt", @service.client.get_blob_properties(key).content_disposition)

    url = @service.url(key, expires_in: 2.minutes, disposition: :attachment, content_type: nil, filename: ActiveStorage::Filename.new("test.html"))
    response = Net::HTTP.get_response(URI(url))
    assert_match(/attachment;.*test\.html/, response["Content-Disposition"])
  ensure
    @service.delete key
  end

  test "upload with custom_metadata" do
    key  = SecureRandom.base58(24)
    data = "Foobar"

    @service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data), filename: ActiveStorage::Filename.new("test.txt"), custom_metadata: { "foo" => "baz" })
    url = @service.url(key, expires_in: 2.minutes, disposition: :inline, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))

    response = Net::HTTP.get_response(URI(url))
    assert_equal("baz", response["x-ms-meta-foo"])
  ensure
    @service.delete key
  end

  test "update metadata" do
    key  = SecureRandom.base58(24)
    data = "Something else entirely!"
    checksum = OpenSSL::Digest::MD5.base64digest(data)
    @service.upload(key, StringIO.new(data), checksum: checksum, content_type: "text/plain", custom_metadata: { "foo" => "bar" })

    @service.update_metadata(key, content_type: "image/png", disposition: :attachment, filename: ActiveStorage::Filename.new("test.png"), custom_metadata: { "baz" => "qux" })
    blob = @service.client.get_blob_properties(key)

    assert_equal "image/png", blob.content_type
    assert_equal "attachment; filename=\"test.png\"; filename*=UTF-8''test.png", blob.content_disposition
    assert_equal checksum, blob.checksum
    assert_equal({ baz: "qux" }, blob.metadata)
    assert_equal data, @service.download(key)
  ensure
    @service.delete key
  end

  test "update metadata keeps the content disposition when no disposition is given" do
    key  = SecureRandom.base58(24)
    data = "Something else entirely!"
    @service.upload(key, StringIO.new(data), content_type: "text/plain", disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"))

    @service.update_metadata(key, content_type: "text/csv")
    blob = @service.client.get_blob_properties(key)

    assert_equal "text/csv", blob.content_type
    assert_equal "inline; filename=\"test.txt\"; filename*=UTF-8''test.txt", blob.content_disposition
  ensure
    @service.delete key
  end

  test "update metadata raises for a missing blob" do
    assert_raises(ActiveStorage::FileNotFoundError) do
      @service.update_metadata(SecureRandom.base58(24), content_type: "text/plain")
    end
  end

  test "changing a blob's content type updates the stored blob" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("a,b\n1,2\n"), filename: "data.csv", content_type: "text/plain", identify: false, service_name: :azure)

    blob.update!(content_type: "text/csv")

    assert_equal "text/csv", @service.client.get_blob_properties(blob.key).content_type
  ensure
    blob&.purge
  end

  test "cache control is applied to uploads, direct uploads and composed blobs" do
    service = ActiveStorage::Service.configure(:azure, SERVICE_CONFIGURATIONS.deep_merge(azure: { cache_control: "public, max-age=3600" }))
    data = "Something else entirely!"
    upload_key, direct_key, composed_key = 3.times.map { SecureRandom.base58(24) }

    service.upload(upload_key, StringIO.new(data))
    assert_equal "public, max-age=3600", service.client.get_blob_properties(upload_key).cache_control

    checksum = OpenSSL::Digest::MD5.base64digest(data)
    headers = service.headers_for_direct_upload(direct_key, checksum: checksum, content_type: "text/plain")
    assert_equal "public, max-age=3600", headers["x-ms-blob-cache-control"]

    uri = URI.parse(service.url_for_direct_upload(direct_key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum))
    request = Net::HTTP::Put.new(uri.request_uri)
    request.body = data
    headers.each { |k, v| request.add_field(k, v) }
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.port == 443) { |http| http.request(request) }
    assert_equal "public, max-age=3600", service.client.get_blob_properties(direct_key).cache_control

    service.compose([ upload_key, direct_key ], composed_key)
    assert_equal "public, max-age=3600", service.client.get_blob_properties(composed_key).cache_control
  ensure
    [ upload_key, direct_key, composed_key ].compact.each { |key| service&.delete(key) }
  end

  test "direct upload headers have no cache control by default" do
    headers = @service.headers_for_direct_upload(@key, checksum: "", content_type: "text/plain")

    assert_not headers.key?("x-ms-blob-cache-control")
  end

  test "signed URL generation" do
    url = @service.url(@key, expires_in: 5.minutes,
                       disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

    assert_match(/(\S+)&rscd=inline%3B\+filename%3D%22avatar\.png%22%3B\+filename\*%3DUTF-8%27%27avatar\.png&rsct=image%2Fpng/, url)
    assert_match SERVICE_CONFIGURATIONS[:azure][:container], url
  end

  test "uploading a tempfile" do
    key  = SecureRandom.base58(24)
    data = "Something else entirely!"

    Tempfile.open do |file|
      file.write(data)
      file.rewind
      @service.upload(key, file)
    end

    assert_equal data, @service.download(key)
  ensure
    @service.delete(key)
  end

  test "composing a blob from one source blob" do
    key  = SecureRandom.base58(24)
    data = "Something else entirely!"

    Tempfile.open do |file|
      file.write(data)
      file.rewind
      @service.upload(key, file)
    end

    assert_equal data, @service.download(key)

    copy_key = SecureRandom.base58(24)
    @service.compose([ key ], copy_key)

    assert_equal data, @service.download(copy_key)
  ensure
    @service.delete key
    @service.delete copy_key
  end
end
