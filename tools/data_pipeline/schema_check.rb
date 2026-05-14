#!/usr/bin/env ruby
# frozen_string_literal: true

# Schema-stability gate for schema_version 4.
#
# v4 (current): adds optional `series.quarterly` block to CPI files.
# v3 files remain readable, but every fresh fetcher run upgrades the file
# to v4 — so the on-disk gate locks new writes to the current version.
#
# Asserts every bundled data file has exactly the expected top-level keys
# and that data/manifest.json references every CPI/FX file present. New keys
# require a deliberate `schema_version` bump and code review — not a silent
# data refresh.
#
# Exits 0 on success. Exits 1 with a diff message on any mismatch.

require "json"

module Tools
  module DataPipeline
    module SchemaCheck
      ROOT = File.expand_path("../..", __dir__)
      DATA = File.join(ROOT, "data")
      EXPECTED_VERSION = 4

      CPI_KEYS = %w[country index provenance providers schema_version series].freeze
      FX_YEAR_REQUIRED_KEYS = %w[base provenance providers rates schema_version year].freeze
      FX_ANNUAL_KEYS = %w[annual base provenance providers schema_version].freeze
      MANIFEST_KEYS = %w[countries fx generated_at schema_version].freeze

      module_function

      def run
        failures = []
        manifest = check_manifest(failures)
        check_cpi_files(failures)
        check_fx_files(failures)
        check_manifest_coverage(manifest, failures) if manifest
        report(failures)
      end

      def assert_schema_version(path, parsed, failures)
        v = parsed["schema_version"]
        failures << "#{path}: schema_version is #{v.inspect}, expected #{EXPECTED_VERSION}" unless v == EXPECTED_VERSION
      end

      def check_keys(path, parsed, required, failures, optional: [])
        actual = parsed.keys
        missing = required - actual
        extra   = actual - required - optional
        return if missing.empty? && extra.empty?

        failures << "#{path}: top-level key mismatch\n  " \
                    "required: #{required.sort.inspect}\n  " \
                    "optional: #{optional.sort.inspect}\n  " \
                    "actual:   #{actual.sort.inspect}\n  " \
                    "missing:  #{missing.inspect}\n  " \
                    "extra:    #{extra.inspect}"
      end

      def load_json(path, failures)
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        failures << "#{path}: invalid JSON (#{e.message})"
        nil
      end

      def check_manifest(failures)
        path = File.join(DATA, "manifest.json")
        unless File.exist?(path)
          failures << "data/manifest.json missing — required for v#{EXPECTED_VERSION}"
          return nil
        end
        parsed = load_json(path, failures)
        return nil unless parsed

        assert_schema_version(path, parsed, failures)
        check_keys(path, parsed, MANIFEST_KEYS, failures)
        parsed
      end

      def check_cpi_files(failures)
        Dir[File.join(DATA, "cpi", "*.json")].each do |p|
          next if File.basename(p) == "placeholder.json"

          parsed = load_json(p, failures)
          next unless parsed

          assert_schema_version(p, parsed, failures)
          check_keys(p, parsed, CPI_KEYS, failures)
        end
      end

      def check_fx_files(failures)
        Dir[File.join(DATA, "fx", "usd", "*.json")].each do |p|
          parsed = load_json(p, failures)
          next unless parsed

          assert_schema_version(p, parsed, failures)
          if File.basename(p) == "_annual.json"
            check_keys(p, parsed, FX_ANNUAL_KEYS, failures)
          else
            check_keys(p, parsed, FX_YEAR_REQUIRED_KEYS, failures)
          end
        end
      end

      def check_manifest_coverage(manifest, failures)
        declared_countries = (manifest["countries"] || []).map { |c| c["cpi_file"] }
        on_disk_countries  = Dir[File.join(DATA, "cpi", "*.json")]
                             .reject { |p| File.basename(p) == "placeholder.json" }
                             .map { |p| "cpi/#{File.basename(p)}" }
                             .sort
        missing = on_disk_countries - declared_countries
        extra   = declared_countries - on_disk_countries
        failures << "manifest.countries missing files: #{missing.inspect}" if missing.any?
        failures << "manifest.countries references missing files: #{extra.inspect}" if extra.any?

        declared_years = (manifest.dig("fx", "daily_years") || []).sort
        on_disk_years  = Dir[File.join(DATA, "fx", "usd", "*.json")]
                         .reject { |p| File.basename(p) == "_annual.json" }
                         .map { |p| File.basename(p, ".json").to_i }
                         .sort
        return if declared_years == on_disk_years

        failures << "manifest.fx.daily_years mismatch: declared #{declared_years.inspect} vs on-disk #{on_disk_years.inspect}"
      end

      def report(failures)
        if failures.empty?
          puts "Schema stability OK: every data file matches schema v#{EXPECTED_VERSION}."
          0
        else
          warn "Schema stability FAILED:"
          failures.each { |f| warn f }
          1
        end
      end
    end
  end
end

exit(Tools::DataPipeline::SchemaCheck.run) if __FILE__ == $PROGRAM_NAME
