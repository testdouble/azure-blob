# frozen_string_literal: true

require "rails/service/shared_service_tests"

class ActiveStorage::Service::AzureBlobPersistentConnectionsServiceTest < ActiveSupport::TestCase
  SERVICE = ActiveStorage::Service.configure(:azure, azure: SERVICE_CONFIGURATIONS[:azure].merge(persistent_connections: true))

  include ActiveStorage::Service::SharedServiceTests
end
