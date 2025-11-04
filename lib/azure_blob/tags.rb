require "rexml/document"

module AzureBlob
  class Tags # :nodoc:
    def self.from_response(response)
      document = REXML::Document.new(response)
      tags = {}
      document.elements.each("Tags/TagSet/Tag") do |tag|
        key = tag.elements["Key"].text
        value = tag.elements["Value"].text
        tags[key] = value
      end
      new(tags)
    end

    def initialize(tags = nil)
      @tags = tags || {}
    end

    def headers
      return {} if @tags.empty?

      {
        "x-ms-tags":
        @tags.map do |key, value|
          %(#{key}=#{value})
        end.join("&"),
      }
    end

    def to_h
      @tags
    end

    def to_xml
      doc = REXML::Document.new
      doc << REXML::XMLDecl.new('1.0', 'utf-8')

      root = doc.add_element('Tags')
      tag_set = root.add_element('TagSet')

      @tags.each do |key, value|
        tag_element = tag_set.add_element('Tag')
        tag_element.add_element('Key').text = key.to_s
        tag_element.add_element('Value').text = value.to_s
      end

      doc.to_s
    end
  end
end
