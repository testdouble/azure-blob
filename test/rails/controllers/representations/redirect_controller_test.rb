# frozen_string_literal: true

require "rails/test_helper"
require "rails/database/setup"

class ActiveStorage::Representations::RedirectControllerWithOpenRedirectTest < ActionDispatch::IntegrationTest
  setup { skip if offline? }
  test "showing existing variant stored in azure" do
    with_raise_on_open_redirects(:azure) do
      blob = create_file_blob filename: "racecar.jpg", service_name: :azure

      get rails_blob_representation_url(
        filename: blob.filename,
        signed_blob_id: blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [ 100, 100 ]))

      assert_redirected_to(/racecar\.jpg/)
    end
  end
end
