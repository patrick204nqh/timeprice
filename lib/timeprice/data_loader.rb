# frozen_string_literal: true

require "json"
require_relative "errors"

module Timeprice
  module DataLoader
    SUPPORTED_SCHEMA_VERSION = 1

    DEFAULT_DATA_ROOT = File.expand_path("../../data", __dir__)

    class << self
      def data_root
        ENV["TIMEPRICE_DATA_ROOT"] || @data_root || DEFAULT_DATA_ROOT
      end

      def data_root=(path)
        @data_root = path
        clear_cache!
      end

      def clear_cache!
        @cpi_cache = {}
        @fx_cache = {}
      end

      def load_cpi(country)
        @cpi_cache ||= {}
        key = country.to_s.downcase
        @cpi_cache[[data_root, key]] ||= begin
          path = File.join(data_root, "cpi", "#{key}.json")
          raise UnsupportedCountry, country.to_s.upcase unless File.exist?(path)
          parse_with_schema(path)
        end
      end

      def load_fx_year(year)
        @fx_cache ||= {}
        key = year.to_i
        @fx_cache[[data_root, key]] ||= begin
          path = File.join(data_root, "fx", "usd", "#{key}.json")
          raise DataNotFound, "No FX data for year #{key}" unless File.exist?(path)
          parse_with_schema(path)
        end
      end

      private

      def parse_with_schema(path)
        data = JSON.parse(File.read(path))
        version = data["schema_version"]
        unless version == SUPPORTED_SCHEMA_VERSION
          raise UnsupportedSchemaVersion.new(version, path)
        end
        data
      end
    end
  end
end
