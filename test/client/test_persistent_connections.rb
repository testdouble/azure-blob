# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"

class TestPersistentConnections < TestCase
  # A minimal connection pool: it takes the uri and the request, sends it and returns the response.
  # It keeps the HTTP method of every request it sent, so the tests can tell what went through it.
  class RecordingConnectionPool
    attr_reader :sent

    def initialize
      @sent = []
    end

    def request(uri, request)
      sent << request.method
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
    end
  end

  attr_reader :client, :key, :content

  def setup
    @client = new_client(persistent_connections: ENV["PERSISTENT_CONNECTIONS"] == "true")
    @key = "test-persistent-connections-#{name}-#{SecureRandom.uuid}"
    @content = "Some random content #{Random.rand(200)}"
  end

  def teardown
    client.delete_prefix(key)
  end

  def test_persistent_connections_false_opens_a_connection_per_request
    one_shot_client = new_client(persistent_connections: false)

    connections = count_connections do
      one_shot_client.create_block_blob(key, content)
      assert_equal content, one_shot_client.get_blob(key)
      one_shot_client.delete_blob(key)
    end

    assert_equal 3, connections
  end

  def test_persistent_connections_true_reuses_the_connection
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

  # Four threads share one client. Each thread uploads, downloads and deletes its own blob.
  def test_persistent_connections_true_with_several_threads
    persistent_client = new_client(persistent_connections: true)

    connections = count_connections do
      threads = 4.times.map do |number|
        Thread.new do
          thread_key = "#{key}/#{number}"
          persistent_client.create_block_blob(thread_key, "content #{number}")
          assert_equal "content #{number}", persistent_client.get_blob(thread_key)
          persistent_client.delete_blob(thread_key)
        end
      end
      threads.each(&:join)
    end

    # 12 requests in total, on at most one connection per thread.
    assert_operator connections, :<=, 4
  end

  def test_reuses_the_connection_by_default_when_net_http_persistent_is_loaded
    require "net/http/persistent"
    default_client = new_client

    connections = count_connections do
      default_client.create_block_blob(key, content)
      assert_equal content, default_client.get_blob(key)
      default_client.delete_blob(key)
    end

    assert_equal 1, connections
  end

  # Runs in another process, because net-http-persistent cannot be unloaded from this one.
  def test_no_connection_pool_by_default_when_net_http_persistent_is_not_loaded
    script = <<~RUBY
      require "azure_blob"
      connection_pool = AzureBlob::Client.new(account_name: "account", access_key: "key", container: "container").send(:connection_pool)
      net_http_persistent = defined?(Net::HTTP::Persistent)
      exit connection_pool.nil? && net_http_persistent.nil?
    RUBY

    assert system(RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", script)
  end

  def test_connection_pool_option
    connection_pool = RecordingConnectionPool.new
    custom_client = new_client(connection_pool:)

    custom_client.create_block_blob(key, content)
    assert_equal content, custom_client.get_blob(key)
    custom_client.delete_blob(key)

    assert_equal [ "PUT", "GET", "DELETE" ], connection_pool.sent
  end

  def test_connection_pool_option_with_a_class
    custom_client = new_client(connection_pool: RecordingConnectionPool)

    custom_client.create_block_blob(key, content)
    custom_client.delete_blob(key)

    assert_equal [ "PUT", "DELETE" ], custom_client.send(:connection_pool).sent
  end

  def test_connection_pool_option_with_the_name_of_a_class
    custom_client = new_client(connection_pool: "TestPersistentConnections::RecordingConnectionPool")

    custom_client.create_block_blob(key, content)
    custom_client.delete_blob(key)

    assert_equal [ "PUT", "DELETE" ], custom_client.send(:connection_pool).sent
  end

  def test_connection_pool_option_with_persistent_connections_false
    connection_pool = RecordingConnectionPool.new
    custom_client = new_client(connection_pool:, persistent_connections: false)

    custom_client.create_block_blob(key, content)

    assert_equal [ "PUT" ], connection_pool.sent
  end

  def test_persistent_connections_true_without_net_http_persistent
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
