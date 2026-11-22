# frozen_string_literal: true

require "rails/service/shared_service_tests"

# The dummy app loads net-http-persistent from the Gemfile, so the other service tests run with persistent connections.
class ActiveStorage::Service::AzureBlobWithoutPersistentConnectionsServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service.configure(:azure, azure: SERVICE_CONFIGURATIONS[:azure].merge(persistent_connections: false))

  include ActiveStorage::Service::SharedServiceTests
end
