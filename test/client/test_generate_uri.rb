require_relative "test_helper"

class TestGenerateUri < TestCase
  def setup
    @client = AzureBlob::Client.new(
      account_name: "testaccount",
      access_key: "ACCESS-KEY",
      container: "test-container"
    )
  end

  def test_generate_uri_with_special_characters
    test_cases = {
      "container/simple.txt" => "https://testaccount.blob.core.windows.net/container/simple.txt",
      "container/path/to/file.txt" => "https://testaccount.blob.core.windows.net/container/path/to/file.txt",
      "container\\backslash\\path.txt" => "https://testaccount.blob.core.windows.net/container/backslash/path.txt",
      "container/file with spaces.txt" => "https://testaccount.blob.core.windows.net/container/file%20with%20spaces.txt",
      "container/file+with+plus.txt" => "https://testaccount.blob.core.windows.net/container/file%2Bwith%2Bplus.txt",
      "container/file?with?question.txt" => "https://testaccount.blob.core.windows.net/container/file%3Fwith%3Fquestion.txt",
      "container/file#with#hash.txt" => "https://testaccount.blob.core.windows.net/container/file%23with%23hash.txt",
      "container/file&with&ampersand.txt" => "https://testaccount.blob.core.windows.net/container/file%26with%26ampersand.txt",
      "container/file%with%percent.txt" => "https://testaccount.blob.core.windows.net/container/file%25with%25percent.txt",
      "container/file<with>brackets.txt" => "https://testaccount.blob.core.windows.net/container/file%3Cwith%3Ebrackets.txt",
      "container/file\"with\"quotes.txt" => "https://testaccount.blob.core.windows.net/container/file%22with%22quotes.txt",
      "container/file'with'apostrophe.txt" => "https://testaccount.blob.core.windows.net/container/file%27with%27apostrophe.txt",
      "container/test ?#&<>\"'%+/\\.txt" => "https://testaccount.blob.core.windows.net/container/test%20%3F%23%26%3C%3E%22%27%25%2B//.txt",
    }

    test_cases.each do |input, expected|
      uri = @client.send(:generate_uri, input)
      assert_equal expected, uri.to_s, "Failed for input: #{input}"
    end
  end

  def test_generate_uri_preserves_container_name
    containers = [
      "mycontainer",
      "my-container",
      "container123",
      "my-container-123",
    ]

    containers.each do |container|
      path = "#{container}/file.txt"
      uri = @client.send(:generate_uri, path)
      assert uri.to_s.include?("/#{container}/"), "Container name was incorrectly encoded: #{container}"
    end
  end

  def test_generate_uri_with_utf8_characters
    uri = @client.send(:generate_uri, "test-container/文件名.txt")
    assert_equal "https://testaccount.blob.core.windows.net/test-container/%E6%96%87%E4%BB%B6%E5%90%8D.txt", uri.to_s
  end
end
