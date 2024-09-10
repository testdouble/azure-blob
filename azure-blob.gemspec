# frozen_string_literal: true

require_relative "lib/azure_blob/version"

Gem::Specification.new do |spec|
  spec.name = "azure-blob"
  spec.version = AzureBlob::VERSION
  spec.authors = [ "Joé Dupuis" ]
  spec.email = [ "joe@dupuis.io" ]

  spec.summary = "Azure blob client"
  spec.homepage = "https://github.com/testdouble/azure-blob"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/testdouble/azure-blob/blob/main/CHANGELOG.md"

  spec.add_dependency "rexml"

  spec.files = Dir['lib/**/*.rb', 'Rakefile', 'README.md', 'CHANGELOG.md', 'LICENSE.txt']
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]
end
