# frozen_string_literal: true

require_relative "block_list"
require_relative "blob_list"
require_relative "blob"
require_relative "http"
require "time"
require "base64"

module AzureBlob
  # AzureBlob Client class. You interact with the Azure Blob api
  # through an instance of this class.
  class Client
    def initialize(account_name:, container:, signer:)
      @account_name = account_name
      @container = container
      @signer = signer
    end

    # Create a blob of type block. Will automatically split the the blob in multiple block and send the blob in pieces (blocks) if the blob is too big.
    #
    # When the blob is small enough this method will send the blob through {Put Blob}[https://learn.microsoft.com/en-us/rest/api/storageservices/put-blob]
    #
    # If the blob is too big, the blob is split in blocks sent through a series of {Put Block}[https://learn.microsoft.com/en-us/rest/api/storageservices/put-block] requests
    # followed by a {Put Block List}[https://learn.microsoft.com/en-us/rest/api/storageservices/put-block-list] to commit the block list.
    #
    # Takes a key (path), the content (String or IO object), and options.
    #
    # Options:
    #
    # [+:content_type+]
    #   Will be saved on the blob in Azure.
    # [+:content_disposition+]
    #   Will be saved on the blob in Azure.
    # [+:content_md5+]
    #   Will ensure integrity of the upload. The checksum must be a base64 digest. Can be produced with +OpenSSL::Digest::MD5.base64digest+.
    #   The checksum is only checked on a single upload! To verify checksum when uploading multiple blocks, call directly put_blob_block with
    #   a checksum for each block, then commit the blocks with commit_blob_blocks.
    # [+:block_size+]
    #   Block size in bytes, can be used to force the method to split the upload in smaller chunk. Defaults to +AzureBlob::DEFAULT_BLOCK_SIZE+ and cannot be bigger than +AzureBlob::MAX_UPLOAD_SIZE+
    def create_block_blob(key, content, options = {})
      if content.size > (options[:block_size] || DEFAULT_BLOCK_SIZE)
        put_blob_multiple(key, content, **options)
      else
        put_blob_single(key, content, **options)
      end
    end

    # Returns the full or partial content of the blob
    #
    # Calls to the {Get Blob}[https://learn.microsoft.com/en-us/rest/api/storageservices/get-blob] endpoint.
    #
    # Takes a key (path) and options.
    #
    # Options:
    #
    # [+:start+]
    #   Starting point in bytes
    # [+:end+]
    #   Ending point in bytes
    def get_blob(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-range": options[:start] && "bytes=#{options[:start]}-#{options[:end]}",
      }

      Http.new(uri, headers, signer:).get
    end

    # Delete a blob
    #
    # Calls to {Delete Blob}[https://learn.microsoft.com/en-us/rest/api/storageservices/delete-blob]
    #
    # Takes a key (path) and options.
    #
    # Options:
    # [+:delete_snapshots+]
    #   Sets the value of the x-ms-delete-snapshots header. Default to +include+
    def delete_blob(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-delete-snapshots": options[:delete_snapshots] || "include",
      }

      Http.new(uri, headers, signer:).delete
    end

    # Delete all blobs prefixed by the given prefix.
    #
    # Calls to {List blobs}[https://learn.microsoft.com/en-us/rest/api/storageservices/list-blobs]
    # followed to a series of calls to {Delete Blob}[https://learn.microsoft.com/en-us/rest/api/storageservices/delete-blob]
    #
    # Takes a prefix and options
    #
    # Look delete_blob for the list of options.
    def delete_prefix(prefix, options = {})
      results = list_blobs(prefix:)
      results.each { |key| delete_blob(key) }
    end

    # Returns a BlobList containing a list of keys (paths)
    #
    # Calls to {List blobs}[https://learn.microsoft.com/en-us/rest/api/storageservices/list-blobs]
    #
    # Options:
    # [+:prefix+]
    #   Prefix of the blobs to be listed. Defaults to listing everything in the container.
    # [:+max_results+]
    #   Maximum number of results to return per page.
    def list_blobs(options = {})
      uri = generate_uri(container)
      query = {
        comp: "list",
        restype: "container",
        prefix: options[:prefix].to_s.gsub(/\\/, "/"),
      }
      query[:maxresults] = options[:max_results] if options[:max_results]
      uri.query = URI.encode_www_form(**query)

      fetcher = ->(marker) do
        query[:marker] = marker
        query.reject! { |key, value| value.to_s.empty? }
        uri.query = URI.encode_www_form(**query)
        response = Http.new(uri, signer:).get
      end

      BlobList.new(fetcher)
    end

    # Returns a Blob object without the content.
    #
    # Calls to {Get Blob Properties}[https://learn.microsoft.com/en-us/rest/api/storageservices/get-blob-properties]
    #
    # This can be used to see if the blob exist or obtain metada such as content type, disposition, checksum or Azure custom metadata.
    def get_blob_properties(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      response = Http.new(uri, signer:).head

      Blob.new(response)
    end

    # Return a URI object to a resource in the container. Takes a path.
    #
    # Example: +generate_uri("#{container}/#{key}")+
    def generate_uri(path)
      URI.parse(URI::DEFAULT_PARSER.escape(File.join(host, path)))
    end

    # Returns an SAS signed URI
    #
    # Takes a
    # - key (path)
    # - A permission string (+"r"+, +"rw"+)
    # - expiry as a UTC iso8601 time string
    # - options
    def signed_uri(key, permissions:, expiry:, **options)
      uri = generate_uri("#{container}/#{key}")
      uri.query = signer.sas_token(uri, permissions:, expiry:, **options)
      uri
    end

    # Creates a Blob of type append.
    #
    # Calls to {Put Blob}[https://learn.microsoft.com/en-us/rest/api/storageservices/put-blob]
    #
    # You are expected to append blocks to the blob with append_blob_block after creating the blob.
    # Options:
    #
    # [+:content_type+]
    #   Will be saved on the blob in Azure.
    # [+:content_disposition+]
    #   Will be saved on the blob in Azure.
    def create_append_blob(key, options = {})
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-blob-type": "AppendBlob",
        "Content-Length": 0,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition],
      }

      Http.new(uri, headers, metadata: options[:metadata], signer:).put(nil)
    end

    # Append a block to an Append Blob
    #
    # Calls to {Append Block}[https://learn.microsoft.com/en-us/rest/api/storageservices/append-block]
    #
    # Options:
    #
    # [+:content_md5+]
    #   Will ensure integrity of the upload. The checksum must be a base64 digest. Can be produced with +OpenSSL::Digest::MD5.base64digest+.
    #   The checksum must be the checksum of the block not the blob.
    def append_blob_block(key, content, options = {})
      uri = generate_uri("#{container}/#{key}")
      uri.query = URI.encode_www_form(comp: "appendblock")

      headers = {
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
      }

      Http.new(uri, headers, signer:).put(content)
    end

    # Uploads a block to a blob.
    #
    # Calls to {Put Block}[https://learn.microsoft.com/en-us/rest/api/storageservices/put-block]
    #
    # Returns the id of the block. Required to commit the list of blocks to a blob.
    #
    # Options:
    #
    # [+:content_md5+]
    #   Must be the checksum for the block not the blob. The checksum must be a base64 digest. Can be produced with +OpenSSL::Digest::MD5.base64digest+.
    def put_blob_block(key, index, content, options = {})
      block_id = generate_block_id(index)
      uri = generate_uri("#{container}/#{key}")
      uri.query = URI.encode_www_form(comp: "block", blockid: block_id)

      headers = {
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "Content-MD5": options[:content_md5],
      }

      Http.new(uri, headers, signer:).put(content)

      block_id
    end

    # Commits the list of blocks to a blob.
    #
    # Calls to {Put Block List}[https://learn.microsoft.com/en-us/rest/api/storageservices/put-block-list]
    #
    # Takes a key (path) and an array of block ids
    #
    # Options:
    #
    # [+:content_md5+]
    #   This is the checksum for the whole blob. The checksum is saved on the blob, but it is not validated!
    #   Add a checksum for each block if you want Azure to validate integrity.
    def commit_blob_blocks(key, block_ids, options = {})
      block_list = BlockList.new(block_ids)
      content = block_list.to_s
      uri = generate_uri("#{container}/#{key}")
      uri.query = URI.encode_www_form(comp: "blocklist")

      headers = {
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "x-ms-blob-content-md5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition],
      }

      Http.new(uri, headers, metadata: options[:metadata], signer:).put(content)
    end

    private

    def generate_block_id(index)
      Base64.urlsafe_encode64(index.to_s.rjust(6, "0"))
    end

    def put_blob_multiple(key, content, options = {})
      content = StringIO.new(content) if content.is_a? String
      block_size = options[:block_size] || DEFAULT_BLOCK_SIZE
      block_count = (content.size.to_f / block_size).ceil
      block_ids = block_count.times.map do |i|
        put_blob_block(key, i, content.read(block_size))
      end

      commit_blob_blocks(key, block_ids, options)
    end

    def put_blob_single(key, content, options = {})
      content = StringIO.new(content) if content.is_a? String
      uri = generate_uri("#{container}/#{key}")

      headers = {
        "x-ms-blob-type": "BlockBlob",
        "Content-Length": content.size,
        "Content-Type": options[:content_type],
        "x-ms-blob-content-md5": options[:content_md5],
        "x-ms-blob-content-disposition": options[:content_disposition],
      }

      Http.new(uri, headers, metadata: options[:metadata], signer:).put(content.read)
    end

    attr_reader :account_name, :signer, :container, :http

    def host
      "https://#{account_name}.blob.core.windows.net"
    end
  end
end
