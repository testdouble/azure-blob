# frozen_string_literal: true

require_relative "lib/azure_blob_storage/version"

Gem::Specification.new do |spec|
  spec.name = "azure-blob-storage"
  spec.version = AzureBlobStorage::VERSION
  spec.authors = ["Joé Dupuis"]
  spec.email = ["joe@dupuis.io"]

  spec.summary = "Azure blob backend for Active Storage"
  spec.homepage = "https://github.com/JoeDupuis/azure-blob-storage"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/JoeDupuis/azure-blob-storage/blob/main/CHANGELOG.md"

  spec.add_dependency "rexml"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end