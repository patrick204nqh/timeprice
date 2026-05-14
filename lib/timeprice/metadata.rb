# frozen_string_literal: true

require_relative "data_loader"
require_relative "supported"
require_relative "version"
require_relative "metadata_snapshot"

module Timeprice
  # Describes the bundled dataset so external surfaces (the website, other
  # tools) can render dropdowns, date pickers, and version pills without
  # hardcoding country lists, currency lists, or date ranges.
  #
  # See {Timeprice.metadata} for the public entry point.
  #
  # @api private
  # Direct references will move to `Timeprice::Internal::Metadata` in a
  # future release.
  module Metadata
    # ISO 3166-style display names for the countries shipped today.
    COUNTRY_NAMES = {
      "AU" => "Australia",
      "CA" => "Canada",
      "CN" => "China",
      "EU" => "Eurozone",
      "JP" => "Japan",
      "KR" => "South Korea",
      "RU" => "Russia",
      "UK" => "United Kingdom",
      "US" => "United States",
      "VN" => "Vietnam",
    }.freeze

    # ISO 4217 display names for the currencies shipped today.
    CURRENCY_NAMES = {
      "AUD" => "Australian dollar",
      "CAD" => "Canadian dollar",
      "CNY" => "Chinese yuan",
      "EUR" => "Euro",
      "GBP" => "British pound",
      "JPY" => "Japanese yen",
      "KRW" => "South Korean won",
      "RUB" => "Russian ruble",
      "USD" => "US dollar",
      "VND" => "Vietnamese dong",
    }.freeze

    module_function

    # Build the metadata snapshot.
    # @return [MetadataSnapshot]
    def build
      manifest = DataLoader.load_manifest
      countries = (manifest["countries"] || []).map { |c| country_entry(c) }
      currencies = Supported.currencies.map { |code| { code: code, name: CURRENCY_NAMES[code] || code } }
      MetadataSnapshot.new(
        version: VERSION,
        generated_at: manifest["generated_at"],
        countries: deep_freeze(countries),
        currencies: deep_freeze(currencies),
        fx: deep_freeze(fx_entry(manifest))
      )
    end

    # Range info comes from the manifest (`cpi_ranges`), pre-computed at
    # manifest generation time. Falls back to walking the CPI file for any
    # country missing the field — older manifests, or local data roots
    # produced by hand.
    def country_entry(country)
      code = country["code"]
      ranges = country["cpi_ranges"] || derive_cpi_ranges(code)
      per_granularity = ranges.each_with_object({}) do |(gran, range), acc|
        acc[gran.to_sym] = { min: range["min"], max: range["max"] }
      end
      {
        code: code,
        name: COUNTRY_NAMES[code] || code,
        currency: country["currency"],
        granularities: country["granularities"] || per_granularity.keys.map(&:to_s),
        cpi: per_granularity,
      }
    end

    def derive_cpi_ranges(code)
      cpi = DataLoader.load_cpi(code)
      series = cpi["series"] || {}
      series.each_with_object({}) do |(granularity, points), acc|
        next unless points.is_a?(Hash) && !points.empty?

        keys = points.keys.sort
        acc[granularity] = { "min" => keys.first, "max" => keys.last }
      end
    end

    # Bounds come from the manifest (`fx.daily_min`/`fx.daily_max`). Older
    # manifests without those keys: peek at the earliest/latest year files.
    def fx_entry(manifest)
      fx = manifest["fx"] || {}
      base = fx["base"]
      years = fx["daily_years"] || []
      return { base: base, daily_min: nil, daily_max: nil } if years.empty?

      daily_min = fx["daily_min"]
      daily_max = fx["daily_max"]
      if daily_min.nil? || daily_max.nil?
        first = DataLoader.load_fx_year(years.min)
        last  = DataLoader.load_fx_year(years.max)
        daily_min ||= (first["rates"] || {}).keys.min
        daily_max ||= (last["rates"] || {}).keys.max
      end
      { base: base, daily_min: daily_min, daily_max: daily_max }
    end

    def deep_freeze(value)
      case value
      when Hash  then value.each_value { |v| deep_freeze(v) }.freeze
      when Array then value.each { |v| deep_freeze(v) }.freeze
      else value.frozen? ? value : value.freeze
      end
    end
  end
end
