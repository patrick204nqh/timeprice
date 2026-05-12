# frozen_string_literal: true

require_relative "data_loader"
require_relative "supported"
require_relative "version"

module Timeprice
  # Describes the bundled dataset so external surfaces (the website, other
  # tools) can render dropdowns, date pickers, and version pills without
  # hardcoding country lists, currency lists, or date ranges.
  #
  # See {Timeprice.metadata} for the public entry point.
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

    # Build the metadata snapshot. Result is a frozen, JSON-serialisable Hash.
    # @return [Hash]
    def build
      manifest = DataLoader.load_manifest
      countries = (manifest["countries"] || []).map { |c| country_entry(c) }
      currencies = Supported.currencies.map { |code| { code: code, name: CURRENCY_NAMES[code] || code } }
      deep_freeze(
        version: VERSION,
        generated_at: manifest["generated_at"],
        countries: countries,
        currencies: currencies,
        fx: fx_entry(manifest)
      )
    end

    def country_entry(country)
      code = country["code"]
      cpi = DataLoader.load_cpi(code)
      series = cpi["series"] || {}
      per_granularity = {}
      series.each do |granularity, points|
        next unless points.is_a?(Hash) && !points.empty?

        keys = points.keys.sort
        per_granularity[granularity.to_sym] = { min: keys.first, max: keys.last }
      end
      {
        code: code,
        name: COUNTRY_NAMES[code] || code,
        currency: country["currency"],
        granularities: country["granularities"] || per_granularity.keys.map(&:to_s),
        cpi: per_granularity,
      }
    end

    # Compute the actual first/last daily FX date by peeking at the earliest
    # and latest year files. Keeps the manifest schema unchanged — `daily_years`
    # is the source of truth for which years ship, and we read the boundaries
    # straight from those files.
    def fx_entry(manifest)
      base = manifest.dig("fx", "base")
      years = manifest.dig("fx", "daily_years") || []
      return { base: base, daily_min: nil, daily_max: nil } if years.empty?

      first = DataLoader.load_fx_year(years.min)
      last  = DataLoader.load_fx_year(years.max)
      {
        base: base,
        daily_min: (first["rates"] || {}).keys.min,
        daily_max: (last["rates"] || {}).keys.max,
      }
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
