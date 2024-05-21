# frozen_string_literal: true

require "net/http"

module AzureBlobStorage
  class HTTP
    def initialize(uri, headers, signer:, debug: false)
      @signer = signer
      @headers = headers
      @uri = uri

      @http = Net::HTTP.new(uri.hostname, uri.port)
      @http.use_ssl = uri.port == 443
      @http.set_debug_output($stdout) if debug
    end

    def get
      headers[:Authorization] = signer.authorization_header(uri:, verb: "GET", headers:)
      @response = http.start do |http|
        http.get(uri, headers)
      end
      raise_error  unless success?
      response.body
    end

    def put(content)
      headers[:Authorization] = signer.authorization_header(uri:, verb: "PUT", headers:)
      @response = http.start do |http|
        http.put(uri, content, headers)
      end
      raise_error  unless success?
      true
    end

    def head
      headers[:Authorization] = signer.authorization_header(uri:, verb: "HEAD", headers:)
      @response = http.start do |http|
        http.head(uri, headers)
      end
      raise_error  unless success?
      response
    end

    def delete
      headers[:Authorization] = signer.authorization_header(uri:, verb: "DELETE", headers:)
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

    def raise_error
      raise error_from_status.new(@response.body)
    end

    def status
      @status ||= Net::HTTPResponse::CODE_TO_OBJ[response.code]
    end

    def error_from_status
      if status == Net::HTTPNotFound
        FileNotFoundError
      else
        Error
      end
    end

    attr_accessor :host, :http, :signer, :response, :headers, :uri
  end
end
