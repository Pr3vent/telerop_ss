# frozen_string_literal: true

require_relative "lib/telerop_ss/version"

Gem::Specification.new do |spec|
  spec.name = "telerop_ss"
  spec.version = TeleropSs::VERSION
  spec.authors = ["Jochen"]
  spec.email = ["jochen@pr3vent.com"]

  spec.summary = "TeleROP severity score (telerop_ss) calculation"
  spec.description = "Shared, versioned scoring of ROP eye annotations (zone, stage, plus, AROP)."
  spec.license = "Nonstandard"
  spec.required_ruby_version = ">= 3.1"

  # Private gem: never push to rubygems.org. Consumed via git or path in the host Gemfile.
  spec.metadata["allowed_push_host"] = "none"

  spec.files = Dir["lib/**/*.rb", "lib/telerop_ss/rules/*.yml", "README.md"]
  spec.require_paths = ["lib"]
end
