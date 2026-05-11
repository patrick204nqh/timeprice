# frozen_string_literal: true

require "json"
require_relative "errors"

module Timeprice
  # Loads and caches the bundled JSON data files. Override the search root
  # by setting `TIMEPRICE_DATA_ROOT` in the environment or assigning
  # {DataLoader.data_root=}.
  module DataLoader
    SUPPORTED_SCHEMA_VERSION = 4

    # Files written by older toolchains remain readable: v3 is monthly+annual
    # only; v4 adds an optional `series.quarterly` block.
    SUPPORTED_SCHEMA_VERSIONS = [3, 4].freeze

    DEFAULT_DATA_ROOT = File.expand_path("../../data", __dir__)

    class << self
      # @return [String] absolute path to the directory containing `cpi/`, `fx/`, `manifest.json`.
      def data_root
        ENV["TIMEPRICE_DATA_ROOT"] || @data_root || DEFAULT_DATA_ROOT
      end

      # Override the data root and clear caches. Mostly useful in tests.
      # @param path [String]
      # @return [void]
      def data_root=(path)
        @data_root = path
        clear_cache!
      end

      # Drop in-memory caches of parsed data files.
      # @return [void]
      def clear_cache!
        @cpi_cache = {}
        @fx_cache = {}
        @manifest_cache = {}
        @annual_fallback_cache = {}
      end

      # Load the top-level manifest describing the bundled dataset.
      # @return [Hash]
      # @raise [DataNotFound] if `manifest.json` is missing
      def load_manifest
        manifest_cache[data_root] ||= begin
          path = File.join(data_root, "manifest.json")
          unless File.exist?(path)
            raise DataNotFound, "manifest.json missing (looked in #{path}). " \
                                "Check TIMEPRICE_DATA_ROOT or reinstall the gem."
          end

          parse_with_schema(path)
        end
      end

      # Load the CPI series for a supported country.
      # @param country [String]
      # @return [Hash] parsed JSON with "series" / "index" / "provenance" / "providers"
      # @raise [UnsupportedCountry] if `country` is not in {Supported.countries}
      # @raise [DataNotFound]       if the file is missing
      # @raise [UnsupportedSchemaVersion] if the file uses a future schema
      def load_cpi(country)
        key = country.to_s.downcase
        code = country.to_s.upcase
        cpi_cache[[data_root, key]] ||= begin
          raise UnsupportedCountry, code unless Supported.country?(code)

          path = File.join(data_root, "cpi", "#{key}.json")
          unless File.exist?(path)
            raise DataNotFound, "CPI data file missing for #{code} (looked in #{path}). " \
                                "Check TIMEPRICE_DATA_ROOT or reinstall the gem."
          end

          parse_with_schema(path)
        end
      end

      # Load the FX rates for a year.
      # @param year [Integer, String]
      # @return [Hash] parsed JSON with `rates` (and optional `annual`) blocks
      # @raise [DataNotFound] if the per-year file is missing
      def load_fx_year(year)
        key = year.to_i
        fx_cache[[data_root, key]] ||= begin
          path = File.join(data_root, "fx", "usd", "#{key}.json")
          raise DataNotFound, "No FX data for year #{key}" unless File.exist?(path)

          parse_with_schema(path)
        end
      end

      # Load the sparse historical FX annual-only fallback file, if present.
      # Returns nil when no fallback file ships with this data root.
      # @return [Hash, nil]
      def load_fx_annual_fallback
        return @annual_fallback_cache[data_root] if @annual_fallback_cache&.key?(data_root)

        @annual_fallback_cache ||= {}
        path = File.join(data_root, "fx", "usd", "_annual.json")
        @annual_fallback_cache[data_root] = File.exist?(path) ? parse_with_schema(path) : nil
      end

      private

      def cpi_cache
        @cpi_cache ||= {}
      end

      def fx_cache
        @fx_cache ||= {}
      end

      def manifest_cache
        @manifest_cache ||= {}
      end

      def parse_with_schema(path)
        data = JSON.parse(File.read(path))
        version = data["schema_version"]
        raise UnsupportedSchemaVersion.new(version, path) unless SUPPORTED_SCHEMA_VERSIONS.include?(version)

        data
      end
    end
  end
end

# Supported is loaded by the top-level entry point. Referenced lazily inside
# load_cpi to avoid a require cycle (Supported reads the manifest via DataLoader).
require_relative "supported" unless defined?(Timeprice::Supported)
