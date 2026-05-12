# frozen_string_literal: true

require_relative "lib/timeprice/version"

Gem::Specification.new do |spec|
  spec.name = "timeprice"
  spec.version = Timeprice::VERSION
  spec.authors = ["Patrick"]
  spec.email = ["patrick204nqh@gmail.com"]

  spec.summary = "Offline historical inflation & FX for Ruby"
  spec.description = "Offline historical inflation & FX for Ruby - bundled data, no API keys, monthly auto-refresh."
  spec.homepage = "https://github.com/patrick204nqh/timeprice"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = "https://github.com/patrick204nqh/timeprice"
  spec.metadata["bug_tracker_uri"] = "https://github.com/patrick204nqh/timeprice/issues"
  spec.metadata["changelog_uri"] = "https://github.com/patrick204nqh/timeprice/blob/main/CHANGELOG.md"
  spec.metadata["github_repo"] = "patrick204nqh/timeprice"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Explicit files list — do NOT rely on `git ls-files` default,
  # which silently drops gitignored paths (including data/).
  spec.files = Dir[
    "lib/**/*", "data/**/*.json", "exe/*",
    "README.md", "CHANGELOG.md", "LICENSE*",
    "NOTICE", "DATA_LICENSES.md"
  ]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.3"

  spec.add_development_dependency "lefthook", "~> 1.8"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.69"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "rubocop-rspec", "~> 3.3"
end
