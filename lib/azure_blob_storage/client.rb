# frozen_string_literal: true

require_relative "signer"
require_relative "block_list"
require_relative "blob_list"
require_relative "blob"
require_relative "http"
require "time"
require "base64"

module AzureBlobStorage
  class Client
    def initialize(account_name:, access_key:, container:)
      @account_name = account_name
      @container = container
      @signer = Signer.new(account_name:, access_key:)
    end

    def create_block_blob(key, content, options = {})
      if content.size > (options[:block_size] || DEFAULT_BLOCK_SIZE)
        put_blob_multiple(key, content, **options)
      else
        put_blob_single(key, content, **options)
      end
    end

    def get_blob(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-range": options[:start] && "bytes=#{options[:start]}-#{options[:end]}",
      }

      Http.new(uri, headers, signer:).get
    end

    def delete_blob(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-delete-snapshots": options[:delete_snapshots] || "include",
      }

      Http.new(uri, headers, signer:).delete
    end

    def delete_prefix(prefix, options = {})
      results = list_blobs(prefix:)
      results.each { |key| delete_blob(key) }
    end

    def list_blobs(options = {})
      uri = generate_uri(container)
      query = {
        comp: "list",
        restype: "container",
        prefix: options[:prefix].to_s.gsub(/\\/, "/"),
      }
      query[:maxresults] = options[:max_results] if options[:max_results]
      uri.query = URI.encode_www_form(**query)

      fetcher = ->(marker) do
        query[:marker] = marker
        query.reject! {|key, value| value.to_s.empty?}
        uri.query = URI.encode_www_form(**query)
        response = Http.new(uri, signer:).get
      end

      BlobList.new(fetcher)
    end

    def get_blob_properties(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      response = Http.new(uri, signer:).head

      Blob.new(response)
    end

    def generate_uri(path)
      URI.parse(URI::DEFAULT_PARSER.escape(File.join(host, path)))
    end

    def signed_uri(key, permissions:, expiry:, **options)
      uri = generate_uri("#{container}/#{key}")
      uri.query = signer.sas_token(uri, permissions:, expiry:, **options)
      uri
    end

    def create_append_blob(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-blob-type": "AppendBlob",
        "Content-Length": 0,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition],
      }

      Http.new(uri, headers, metadata: options[:metadata], signer:).put(nil)
    end

    def append_blob_block(key, content, options = {})
      uri = generate_uri("#{container}/#{key}")
      uri.query = URI.encode_www_form(comp: "appendblock")

      headers = {
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
      }

      Http.new(uri, headers, signer:).put(content)
    end

    def put_blob_block(key, index, content, options = {})
      block_id = generate_block_id(index)
      uri = generate_uri("#{container}/#{key}")
      uri.query = URI.encode_www_form(comp: "block", blockid: block_id)

      headers = {
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
      }

      Http.new(uri, headers, signer:).put(content)

      block_id
    end

    def commit_blob_blocks(key, block_ids, options = {})
      block_list = BlockList.new(block_ids)
      content = block_list.to_s
      uri = generate_uri("#{container}/#{key}")
      uri.query = URI.encode_www_form(comp: "blocklist")

      headers = {
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition],
      }

      Http.new(uri, headers, metadata: options[:metadata], signer:).put(content)
    end

    private

    def generate_block_id(index)
      Base64.urlsafe_encode64(index.to_s.rjust(6, "0"))
    end

    def put_blob_multiple(key, content, options = {})
      content = StringIO.new(content) if content.is_a? String
      block_size = options[:block_size] || DEFAULT_BLOCK_SIZE
      block_count = (content.size.to_f / block_size).ceil
      block_ids = block_count.times.map do |i|
        put_blob_block(key, i, content.read(block_size))
      end

      commit_blob_blocks(key, block_ids, options)
    end

    def put_blob_single(key, content, options = {})
      content = StringIO.new(content) if content.is_a? String
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-blob-type": "BlockBlob",
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition],
      }

      Http.new(uri, headers, metadata: options[:metadata], signer:).put(content.read)
    end

    attr_reader :account_name, :signer, :container, :http

    def host
      "https://#{account_name}.blob.core.windows.net"
    end
  end
end
