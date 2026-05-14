# frozen_string_literal: true

require_relative "errors"

module Timeprice
  # Single source of truth for the on-disk v4 CPI/manifest format. Both the
  # reader ({DataLoader}) and the writer (today: pipeline `CountryFile`)
  # route through here so the schema lives in exactly one place.
  module Schema
    CURRENT_VERSION = 4
    SUPPORTED_VERSIONS = [3, 4].freeze

    KEY_SCHEMA_VERSION = "schema_version"
    KEY_COUNTRY        = "country"
    KEY_INDEX          = "index"
    KEY_SERIES         = "series"
    KEY_PROVENANCE     = "provenance"
    KEY_PROVIDERS      = "providers"

    GRANULARITIES = %i[monthly quarterly annual].freeze

    BASE_YEAR_RE = /\A(?<period>.+?)=100(?:\s*\(rebased\s+(?<rebased>\d{4}-\d{2}-\d{2})\))?\z/

    module_function

    def supported?(version)
      SUPPORTED_VERSIONS.include?(version)
    end

    def assert_supported!(version, path)
      return if supported?(version)

      fail UnsupportedSchemaVersion.new(version, path)
    end

    # Build a CPI payload ready for JSON.dump. Series keys are emitted in a
    # stable order (annual, monthly[, quarterly]) so file diffs stay tight.
    def dump_cpi(country:, base_year:, monthly:, annual:, providers:, provenance:, quarterly: {})
      series = { "annual" => annual, "monthly" => monthly }
      series["quarterly"] = quarterly unless quarterly.empty?
      {
        KEY_SCHEMA_VERSION => CURRENT_VERSION,
        KEY_COUNTRY => country.to_s.upcase,
        KEY_INDEX => serialise_base_year(base_year),
        KEY_SERIES => series,
        KEY_PROVENANCE => provenance,
        KEY_PROVIDERS => providers,
      }
    end

    # Validate a parsed payload (read from disk) against the schema, then
    # return it unchanged. Raises UnsupportedSchemaVersion if the version
    # field is missing or unknown.
    def load_cpi(parsed, path:)
      assert_supported!(parsed[KEY_SCHEMA_VERSION], path)
      parsed
    end

    def serialise_base_year(str)
      m = BASE_YEAR_RE.match(str.to_s)
      if m
        { "base_period" => m[:period], "rebased_at" => m[:rebased] }
      else
        { "base_period" => str.to_s, "rebased_at" => nil }
      end
    end

    def deserialise_base_year(index)
      return nil unless index.is_a?(Hash)

      period = index["base_period"]
      rebased = index["rebased_at"]
      return nil if period.nil?

      rebased ? "#{period}=100 (rebased #{rebased})" : "#{period}=100"
    end
  end
end
