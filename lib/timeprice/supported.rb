# frozen_string_literal: true

module Timeprice
  # Canonical lists of supported country and currency codes, plus the
  # bidirectional currency↔country map used by `Compare` and CLI output.
  #
  # Everything that needs to know "which currency pairs with which CPI series"
  # must read it from here — duplicating the map elsewhere has bitten us before
  # when a new country was added in one place and forgotten in the other.
  module Supported
    COUNTRIES  = %w[US UK EU JP VN].freeze
    CURRENCIES = %w[USD GBP EUR JPY VND].freeze

    COUNTRY_TO_CURRENCY = {
      "US" => "USD",
      "UK" => "GBP",
      "EU" => "EUR",
      "JP" => "JPY",
      "VN" => "VND",
    }.freeze

    CURRENCY_TO_COUNTRY = COUNTRY_TO_CURRENCY.invert.freeze

    module_function

    # @param country [String]
    # @return [Boolean]
    def country?(country)
      COUNTRIES.include?(country.to_s.upcase)
    end

    # @param currency [String]
    # @return [Boolean]
    def currency?(currency)
      CURRENCIES.include?(currency.to_s.upcase)
    end

    # @param currency [String] ISO 4217 code (e.g. "USD")
    # @return [String, nil] country code, or nil if unsupported
    def country_for_currency(currency)
      CURRENCY_TO_COUNTRY[currency.to_s.upcase]
    end

    # @param country [String] country code (e.g. "US")
    # @return [String, nil] currency code, or nil if unsupported
    def currency_for_country(country)
      COUNTRY_TO_CURRENCY[country.to_s.upcase]
    end
  end

  # Back-compat aliases — keep the old top-level constants pointing at the
  # canonical lists so existing requires of "errors" keep working.
  SUPPORTED_COUNTRIES  = Supported::COUNTRIES
  SUPPORTED_CURRENCIES = Supported::CURRENCIES
end
