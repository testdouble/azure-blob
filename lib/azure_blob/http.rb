# frozen_string_literal: true

require_relative "errors"
require_relative "metadata"
require "net/http"
require "rexml"

module AzureBlob
  class Http
    class Error < AzureBlob::Error; end
    class FileNotFoundError < Error; end
    class ForbidenError < Error; end
    class IntegrityError < Error; end

    include REXML

    def initialize(uri, headers = {}, signer: nil, metadata: {}, debug: false)
      @date = Time.now.httpdate
      @uri = uri
      @signer = signer
      @headers = headers.merge(Metadata.new(metadata).headers)
      sanitize_headers

      @http = Net::HTTP.new(uri.hostname, uri.port)
      @http.use_ssl = uri.port == 443
      @http.set_debug_output($stdout) if debug
    end

    def get
      sign_request("GET") if signer
      @response = http.start do |http|
        http.get(uri, headers)
      end
      raise_error  unless success?
      response.body
    end

    def put(content)
      sign_request("PUT") if signer
      @response = http.start do |http|
        http.put(uri, content, headers)
      end
      raise_error  unless success?
      true
    end

    def head
      sign_request("HEAD") if signer
      @response = http.start do |http|
        http.head(uri, headers)
      end
      raise_error  unless success?
      response
    end

    def delete
      sign_request("DELETE") if signer
      @response = http.start do |http|
        http.delete(uri, headers)
      end
      raise_error  unless success?
      response.body
    end

    def success?
      status < Net::HTTPSuccess
    end

    private

    ERROR_MAPPINGS = {
      Net::HTTPNotFound => FileNotFoundError,
      Net::HTTPForbidden => ForbidenError,
    }

    ERROR_CODE_MAPPINGS = {
      "Md5Mismatch" => IntegrityError,
    }

    def sanitize_headers
      headers[:"x-ms-version"] =  API_VERSION
      headers[:"x-ms-date"] = date
      headers[:"Content-Type"] = headers[:"Content-Type"].to_s
      headers[:"Content-Length"] = headers[:"Content-Length"]&.to_s
      headers[:"Content-MD5"] = nil if headers[:"Content-MD5"]&.empty?
      headers.reject! { |_, value| value.nil? }
    end

    def sign_request(method)
      headers[:Authorization] = signer.authorization_header(uri:, verb: method, headers:)
    end

    def raise_error
      raise error_from_response.new(@response.body)
    end

    def status
      @status ||= Net::HTTPResponse::CODE_TO_OBJ[response.code]
    end

    def azure_error_code
      Document.new(response.body).get_elements("//Error/Code").first.get_text.to_s
    end

    def error_from_response
      ERROR_MAPPINGS[status] || ERROR_CODE_MAPPINGS[azure_error_code] || Error
    end

    attr_accessor :host, :http, :signer, :response, :headers, :uri, :date
  end
end
