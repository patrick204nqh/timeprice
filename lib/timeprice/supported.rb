# frozen_string_literal: true

module Timeprice
  # Supported country and currency codes, derived from `data/manifest.json`.
  # Adding a country = drop a CPI file + regenerate the manifest. No code
  # change required.
  #
  # Everything that needs to know "which currency pairs with which CPI series"
  # must read it from here.
  module Supported
    # Currencies with no minor unit — formatted as whole numbers. This is
    # ISO 4217 metadata, not bundled data, so it stays hardcoded.
    ZERO_DECIMAL_CURRENCIES = %w[JPY KRW VND].freeze

    module_function

    # @return [Array<String>] frozen list of supported country codes.
    def countries
      manifest_countries.map { |c| c["code"] }.freeze
    end

    # @return [Array<String>] frozen list of supported currency codes
    #   (the FX base USD plus every currency the manifest declares).
    def currencies
      base = DataLoader.load_manifest.dig("fx", "base")
      ([base] + DataLoader.load_manifest.dig("fx", "currencies")).uniq.freeze
    end

    # @return [Hash{String=>String}] country code → currency code.
    def country_to_currency
      manifest_countries.to_h { |c| [c["code"], c["currency"]] }.freeze
    end

    # @return [Hash{String=>String}] currency code → country code.
    def currency_to_country
      country_to_currency.invert.freeze
    end

    # ISO 4217 minor-unit count for a currency. Falls back to 2 for unknown
    # codes so callers can still render *some* value rather than crashing.
    # @param currency [String]
    # @return [Integer]
    def decimals_for(currency)
      ZERO_DECIMAL_CURRENCIES.include?(currency.to_s.upcase) ? 0 : 2
    end

    # @param country [String]
    # @return [Boolean]
    def country?(country)
      countries.include?(country.to_s.upcase)
    end

    # @param currency [String]
    # @return [Boolean]
    def currency?(currency)
      currencies.include?(currency.to_s.upcase)
    end

    # @param currency [String] ISO 4217 code (e.g. "USD")
    # @return [String, nil] country code, or nil if unsupported
    def country_for_currency(currency)
      currency_to_country[currency.to_s.upcase]
    end

    # @param country [String] country code (e.g. "US")
    # @return [String, nil] currency code, or nil if unsupported
    def currency_for_country(country)
      country_to_currency[country.to_s.upcase]
    end

    class << self
      private

      def manifest_countries
        DataLoader.load_manifest["countries"] || []
      end
    end
  end
end
