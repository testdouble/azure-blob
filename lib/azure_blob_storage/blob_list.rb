# frozen_string_literal: true

require "rexml"

module AzureBlobStorage
  class BlobList
    include REXML
    include Enumerable

    def initialize(fetcher)
      @fetcher = fetcher
    end

    def size
      to_a.size
    end

    def each
      loop do
        fetch
        current_page.each do |key|
          yield key
        end

        break unless marker
      end
    end

    def to_s
      to_a.to_s
    end

    def inspect
      to_a.inspect
    end

    private

    def marker
      document && document.get_elements("//EnumerationResults/NextMarker").first.get_text()&.to_s
    end

    def current_page
      document
        .get_elements("//EnumerationResults/Blobs/Blob/Name")
        .map { |element| element.get_text.to_s }
    end

    def fetch
      @document = Document.new(fetcher.call(marker))
    end

    attr_reader :document, :fetcher
  end
end
