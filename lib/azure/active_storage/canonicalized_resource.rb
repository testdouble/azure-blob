require "cgi"

module Azure::ActiveStorage
  class CanonicalizedResource
    def initialize(uri, account_name, service_name: nil)
      resource = "/#{account_name}#{uri.path.empty? ? "/" : uri.path}"
      resource = "/#{service_name}#{resource}" if service_name
      params = CGI.parse(uri.query.to_s)
        .transform_keys(&:downcase)
        .sort
        .map { |param, value| "#{param}:#{value.map(&:strip).sort.join(",")}" }

      @canonicalized_resource = [resource, *params].join("\n")
    end

    def to_s
      @canonicalized_resource
    end
  end
end
