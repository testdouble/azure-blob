# frozen_string_literal: true

require_relative "active_storage/version"
require_relative "active_storage/client"
require_relative "active_storage/const"

module Azure
  module ActiveStorage
    class Error < StandardError; end
  end
end
