# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require 'azure_blob'

Minitest::TestTask.create

task default: %i[test]

task :test_entra_id do |t|
  ENV["AZURE_ACCESS_KEY"] = nil
  Rake::Task["test"].execute
end

task :flush_test_container do |t|
  AzureBlob::Client.new(
    account_name: ENV["AZURE_ACCOUNT_NAME"],
    access_key: ENV["AZURE_ACCESS_KEY"],
    container: ENV["AZURE_PRIVATE_CONTAINER"],
  ).delete_prefix ''
  AzureBlob::Client.new(
    account_name: ENV["AZURE_ACCOUNT_NAME"],
    access_key: ENV["AZURE_ACCESS_KEY"],
    container: ENV["AZURE_PUBLIC_CONTAINER"],
  ).delete_prefix ''
end
