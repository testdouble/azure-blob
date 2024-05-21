# frozen_string_literal: true

module AzureBlobStorage
  class Blob
    def initialize(response)
      @response = response
    end

    def size
      response.content_length
    end

    def present?
      response.code == "200"
    end

    private

    attr_reader :response
  end
end
