# frozen_string_literal: true

require_relative "signer"
require_relative "block_list"
require "net/http"
require "time"
require "base64"

module Azure::ActiveStorage
  class Client
    def initialize(account_name:, access_key:)
      @account_name = account_name
      @api_version = "2024-05-04"
      @signer = Signer.new(access_key:)

      uri = URI(host)

      @http = Net::HTTP.new(uri.hostname, uri.port)
      @http.use_ssl = true
      @http.set_debug_output($stdout)
    end

    def create_block_blob(container, key, content, options = {})
      if content.size > (options[:block_size] || DEFAULT_BLOCK_SIZE)
        put_blob_multiple(container, key, content, **options)
      else
        put_blob(container, key, content, **options)
      end
    end

    def get_blob(container, key, options = {})
      uri = URI(URI::DEFAULT_PARSER.escape("#{host}/#{container}/#{key}"))
      date = Time.now.httpdate

      headers = {
        "x-ms-version": api_version,
        "x-ms-date": date,
        "x-ms-range": options[:start_range] && "bytes=#{options[:start_range]}-#{options[:end_range]}"
      }.reject { |_, value| value.nil? }

      signature = signer.sign(uri:, account_name:, verb: "GET", headers:)
      headers[:Authorization] = "SharedKey #{account_name}:#{signature}"

      http.start do |http|
        http.get(uri.path, headers)
      end.body
    end

    private

    def put_blob_multiple(container, key, content, options = {})
      content = StringIO.new(content) if content.is_a? String
      block_size = options[:block_size] || DEFAULT_BLOCK_SIZE
      block_count = (content.size.to_f / block_size).ceil
      block_ids = block_count.times.map { |i| Base64.urlsafe_encode64(i.to_s) }
      block_ids.each do |block_id|
        put_blob_block(container, key, block_id, content.read(block_size))
      end

      commit_blob_blocks(container, key, block_ids, options)
    end

    def commit_blob_blocks(container, key, block_ids, options = {})
      block_list = BlockList.new(block_ids)
      content = block_list.to_s
      uri = URI(URI::DEFAULT_PARSER.escape("#{host}/#{container}/#{key}"))

      date = Time.now.httpdate
      headers = {
        "x-ms-version": api_version,
        "x-ms-date": date,
        "Content-Length": content.size.to_s,
        "Content-Type": options[:content_type].to_s, # Net::HTTP doesn't leave this empty if the value is nil
        "Content-MD5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition]
      }.reject { |_, value| value.nil? }

      options[:metadata]&.each do |key, value|
        headers[:"x-ms-meta-#{key}"] = value.to_s
      end

      signature = signer.sign(uri:, account_name:, verb: "PUT", content_length: content.size, headers:, **options.slice(:content_type))
      headers[:Authorization] = "SharedKey #{account_name}:#{signature}"

      http.start do |http|
        http.put(uri.path, content, headers)
      end
    end

    def put_blob_block(container, key, block_id, content, options = {})
      uri = URI(URI::DEFAULT_PARSER.escape("#{host}/#{container}/#{key}"))
      uri.query = URI.encode_www_form(comp: "block", blockid: block_id)

      date = Time.now.httpdate
      headers = {
        "x-ms-version": api_version,
        "x-ms-date": date,
        "Content-Length": content.size.to_s,
        "Content-Type": options[:content_type].to_s, # Net::HTTP doesn't leave this empty if the value is nil
        "Content-MD5": options[:content_md5]
      }.reject { |_, value| value.nil? }

      signature = signer.sign(uri:, account_name:, verb: "PUT", content_length: content.size, headers:, **options.slice(:content_type))
      headers[:Authorization] = "SharedKey #{account_name}:#{signature}"

      http.start do |http|
        http.put(uri, content, headers)
      end
    end

    def put_blob(container, key, content, options = {})
      uri = URI(URI::DEFAULT_PARSER.escape("#{host}/#{container}/#{key}"))
      date = Time.now.httpdate
      headers = {
        "x-ms-version": api_version,
        "x-ms-date": date,
        "x-ms-blob-type": "BlockBlob",
        "Content-Length": content.size.to_s,
        "Content-Type": options[:content_type].to_s, # Net::HTTP doesn't leave this empty if the value is nil
        "Content-MD5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition]
      }.reject { |_, value| value.nil? }

      options[:metadata]&.each do |key, value|
        headers[:"x-ms-meta-#{key}"] = value.to_s
      end

      signature = signer.sign(uri:, account_name:, verb: "PUT", content_length: content.size, headers:, **options.slice(:content_type))
      headers[:Authorization] = "SharedKey #{account_name}:#{signature}"

      http.start do |http|
        http.put(uri.path, content.read, headers)
      end
    end

    attr_reader :account_name, :signer, :container, :api_version, :http

    def host
      "https://#{account_name}.blob.core.windows.net"
    end
  end
end
