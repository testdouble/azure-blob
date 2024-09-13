# frozen_string_literal: true

module AzureBlob
  API_VERSION = "2024-05-04"
  MAX_UPLOAD_SIZE = 256 * 1024 * 1024 # 256 Megabytes
  DEFAULT_BLOCK_SIZE = 128 * 1024 * 1024 # 128 Megabytes
  BLOB_SERVICE = "b"
end
