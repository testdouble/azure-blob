# frozen_string_literal: true

require_relative "errors"
require_relative "metadata"
require "net/http"
require "rexml"

module AzureBlob
  class Http # :nodoc:
    class Error < AzureBlob::Error
      attr_reader :body, :status, :code
      def initialize(body: nil, status: nil, code: nil)
        @body = body
        @status = status
        @code = code
        super(status && [ status, code ].compact.join(" "))
      end

      def inspect
        @body
      end
    end
    class FileNotFoundError < Error; end
    class ForbiddenError < Error; end
    class IntegrityError < Error; end
    class TimeoutError < Error; end

    include REXML

    def initialize(uri, headers = {}, signer: nil, connection_pool: nil, metadata: {}, tags: {}, debug: false, raise_on_error: true)
      @raise_on_error = raise_on_error
      @date = Time.now.httpdate
      @uri = uri
      @signer = signer
      @connection_pool = connection_pool
      @debug = debug
      @headers = headers.merge(
        Metadata.new(metadata).headers,
        Tags.new(tags).headers,
      )

      sanitize_headers
    end

    def get
      sign_request("GET") if signer
      @response = perform(Net::HTTP::Get.new(uri, headers))
      raise_error  unless success?
      response.body
    end

    def put(content = "")
      sign_request("PUT") if signer
      @response = perform(Net::HTTP::Put.new(uri, headers), content)
      raise_error  unless success?
      true
    end

    def post(content = "")
      sign_request("POST") if signer
      @response = perform(Net::HTTP::Post.new(uri, headers), content)
      raise_error  unless success?
      response.body
    end

    def head
      sign_request("HEAD") if signer
      @response = perform(Net::HTTP::Head.new(uri, headers))
      raise_error  unless success?
      response
    end

    def delete
      sign_request("DELETE") if signer
      @response = perform(Net::HTTP::Delete.new(uri, headers))
      raise_error  unless success?
      response.body
    end

    def success?
      status < Net::HTTPSuccess
    end

    private

    # Sends the request through the connection pool when the client has one, which keeps the
    # connection open for the next request. Without one, the request gets a connection of its own.
    def perform(request, body = nil)
      request.body = body if body

      return connection_pool.request(uri, request) if connection_pool

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.port == 443
      http.set_debug_output($stdout) if debug
      http.start { http.request(request) }
    end

    ERROR_MAPPINGS = {
      Net::HTTPNotFound => FileNotFoundError,
      Net::HTTPForbidden => ForbiddenError,
    }

    ERROR_CODE_MAPPINGS = {
      "Md5Mismatch" => IntegrityError,
      "OperationTimedOut" => TimeoutError,
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
      return unless raise_on_error
      raise error_from_response.new(body: @response.body, status: @response.code&.to_i, code: azure_error_code)
    end

    def status
      @status ||= Net::HTTPResponse::CODE_TO_OBJ[response.code]
    end

    def azure_error_code
      response["x-ms-error-code"] || Document.new(response.body.to_s).get_elements("//Error/Code").first&.text
    rescue ParseException
      nil
    end

    def error_from_response
      ERROR_MAPPINGS[status] || ERROR_CODE_MAPPINGS[azure_error_code] || Error
    end

    attr_accessor :host, :connection_pool, :debug, :signer, :response, :headers, :uri, :date, :raise_on_error
  end
end
