# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"

class TestPersistentConnections < TestCase
  # What the +connection+ option expects: an object taking the uri and the request, and returning the response.
  class RecordingConnection
    attr_reader :requests

    def initialize
      @requests = []
    end

    def request(uri, request)
      requests << request
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
    end
  end

  attr_reader :client, :key, :content

  def setup
    @client = new_client
    @key = "test-persistent-connections-#{name}-#{SecureRandom.uuid}"
    @content = "Some random content #{Random.rand(200)}"
  end

  def teardown
    client.delete_prefix(key)
  end

  def test_opens_a_connection_per_request_by_default
    connections = count_connections do
      client.create_block_blob(key, content)
      assert_equal content, client.get_blob(key)
      client.delete_blob(key)
    end

    assert_equal 3, connections
  end

  def test_persistent_connections_reuse_the_connection
    persistent_client = new_client(persistent_connections: true)

    connections = count_connections do
      persistent_client.create_block_blob(key, content)
      assert_equal content, persistent_client.get_blob(key)
      assert_equal content.bytesize, persistent_client.get_blob_properties(key).size
      assert_equal [ key ], persistent_client.list_blobs(prefix: key).to_a
      persistent_client.delete_blob(key)
      refute persistent_client.blob_exist?(key)
    end

    assert_equal 1, connections
  end

  def test_persistent_connections_across_threads
    persistent_client = new_client(persistent_connections: true)
    threads = 4

    connections = count_connections do
      threads.times.map do |thread|
        Thread.new do
          3.times do |index|
            thread_key = "#{key}/#{thread}/#{index}"
            persistent_client.create_block_blob(thread_key, "#{content} #{thread_key}")
            assert_equal "#{content} #{thread_key}", persistent_client.get_blob(thread_key)
            persistent_client.delete_blob(thread_key)
          end
        end
      end.each(&:join)
    end

    assert_includes 1..threads, connections
  end

  def test_connection_option
    connection = RecordingConnection.new
    custom_client = new_client(connection:)

    custom_client.create_block_blob(key, content)
    assert_equal content, custom_client.get_blob(key)
    custom_client.delete_blob(key)

    assert_equal [ Net::HTTP::Put, Net::HTTP::Get, Net::HTTP::Delete ], connection.requests.map(&:class)
  end

  def test_persistent_connections_without_net_http_persistent
    client_without_the_gem = Class.new(AzureBlob::Client) do
      def require(name)
        raise LoadError, "cannot load such file -- #{name}" if name == "net/http/persistent"
        super
      end
    end

    error = assert_raises(AzureBlob::Error) do
      client_without_the_gem.new(account_name: "account", access_key: "key", container: "container", persistent_connections: true)
    end

    assert_match(/net-http-persistent/, error.message)
  end

  private

  def new_client(**options)
    AzureBlob::Client.new(
      account_name: ENV["AZURE_ACCOUNT_NAME"],
      access_key: ENV["AZURE_ACCESS_KEY"],
      container: ENV["AZURE_PRIVATE_CONTAINER"],
      principal_id: ENV["AZURE_PRINCIPAL_ID"],
      use_managed_identities: ENV["USE_MANAGED_IDENTITIES"] == "true",
      host: ENV["STORAGE_BLOB_HOST"],
      **options,
    )
  end

  # Counts the connections opened to the storage account while the block runs.
  # Token requests of managed identities go to another host and are left out.
  def count_connections(&block)
    host = client.generate_uri("").hostname
    count = 0
    trace = TracePoint.new(:call) { |connect| count += 1 if connect.self.address == host }
    trace.enable(target: Net::HTTP.instance_method(:connect), &block)
    count
  end
end
