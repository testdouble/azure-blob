# frozen_string_literal: true
require_relative "signer"
require 'net/http'
require 'time'

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
      uri = URI(URI::Parser.new.escape("#{host}/#{container}/#{key}"))
      date = Time.now.httpdate
      headers = {
        "x-ms-version": api_version,
        "x-ms-date": date,
        "x-ms-blob-type": "BlockBlob",
        "Content-Length": content.size.to_s,
        "Content-Type": options[:content_type].to_s, #Net::HTTP doesn't leave this empty if the value is nil
        "Content-MD5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition]
      }.reject{|_,value| value.nil? }

      options[:metadata]&.each do |key,value|
        headers[:"x-ms-meta-#{key}"] = value.to_s
      end

      signature = signer.sign(uri:, account_name:, verb: "PUT", content_length: content.size, headers:, **options.slice(:content_type))
      headers[:Authorization] = "SharedKey #{account_name}:#{signature}"

      http.start do |http|
        http.put(uri.path, content.read, headers)
      end
    end

    def get_blob(container, key, options = {})
      uri = URI(URI::Parser.new.escape("#{host}/#{container}/#{key}"))
      date = Time.now.httpdate

      headers = {
        "x-ms-version": api_version,
        "x-ms-date": date,
        "x-ms-range": options[:start_range] && "bytes=#{options[:start_range]}-#{options[:end_range]}"
      }.reject{|_,value| value.nil? }

      signature = signer.sign(uri:, account_name:, verb: "GET", headers:)
      headers[:Authorization] = "SharedKey #{account_name}:#{signature}"

      http.start do |http|
        http.get(uri.path, headers)
      end.body
    end

    private


    attr_reader :account_name, :signer, :container, :api_version, :http


    def host
      "https://#{account_name}.blob.core.windows.net"
    end
  end
end
