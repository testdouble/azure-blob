require 'rexml/document'

module AzureBlob
  class Tags
    def initialize(xml_response)
      @xml_response = xml_response
    end

    def to_hash
      document = REXML::Document.new(@xml_response)
      tags = {}
      document.elements.each('Tags/TagSet/Tag') do |tag|
        key = tag.elements['Key'].text
        value = tag.elements['Value'].text
        tags[key] = value
      end
      tags
    end
  end
end
