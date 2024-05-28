# frozen_string_literal: true

require "rails/test_helper"
require "rails/database/setup"

class ActiveStorage::Blobs::RedirectControllerWithOpenRedirectTest < ActionDispatch::IntegrationTest
  test "showing existing blob stored in azure" do
    with_raise_on_open_redirects(:azure) do
      blob = create_file_blob filename: "racecar.jpg", service_name: :azure

      get rails_storage_redirect_url(blob)
      assert_redirected_to(/racecar\.jpg/)
    end
  end
end
