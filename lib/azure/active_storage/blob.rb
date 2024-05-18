# frozen_string_literal: true

require "rexml"

module Azure::ActiveStorage
  class Blob
    def initialize(response)
      @response = response
    end

    def content_length
      response.content_length
    end

    def present?
      response.code == "200"
    end

    private

    attr_reader :response
  end
end
