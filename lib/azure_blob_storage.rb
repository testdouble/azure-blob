# frozen_string_literal: true

require_relative "azure_blob_storage/version"
require_relative "azure_blob_storage/client"
require_relative "azure_blob_storage/const"

module AzureBlobStorage
  class Error < StandardError; end
end
