# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require 'azure_blob'

Minitest::TestTask.create

task default: %i[test]

task :flush_test_container do |t|
  signer = AzureBlob::SharedKeySigner.new(account_name: ENV["AZURE_ACCOUNT_NAME"], access_key: ENV["AZURE_ACCESS_KEY"])

  AzureBlob::Client.new(
    account_name: ENV["AZURE_ACCOUNT_NAME"],
    container: ENV["AZURE_PRIVATE_CONTAINER"],
    signer:
  ).delete_prefix ''
  AzureBlob::Client.new(
    account_name: ENV["AZURE_ACCOUNT_NAME"],
    container: ENV["AZURE_PUBLIC_CONTAINER"],
    signer:
  ).delete_prefix ''
end
