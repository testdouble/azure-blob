module AzureBlobStorage
  class Error < StandardError; end
  class FileNotFoundError < Error; end
  class IntegrityError < Error; end

  def self.error_from_response_type(type)
    if type == Net::HTTPNotFound
      FileNotFoundError
    end
  end
end
