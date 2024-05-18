# frozen_string_literal: true

require "rexml"

module Azure::ActiveStorage
  class BlobList
    include REXML
    def initialize(response)
      @document = Document.new(response)
    end

    def marker
      document.get_elements("//EnumerationResults/NextMarker").first.get_text()
    end

    def to_a
      document.get_elements("//EnumerationResults/Blobs/Blob/Name").map(&:get_text)
    end

    def each
      to_a.each
    end

    def to_s
      to_a.to_s
    end

    def inspect
      to_a.inspect
    end

    private

    attr_reader :document
  end
end
