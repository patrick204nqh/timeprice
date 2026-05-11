# frozen_string_literal: true

require_relative "errors"
require_relative "data_loader"
require_relative "cpi_lookup"

module Timeprice
  # Value object returned by Inflation.adjust.
  #
  # granularity is one of:
  #   :monthly                  — both ends resolved on monthly data
  #   :annual                   — at least one end resolved on annual data
  #   :annual_from_monthly_avg  — at least one end was an annual request resolved
  #                               by averaging 12 months of monthly data
  InflationResult = Data.define(
    :amount, :original_amount, :from, :to, :country,
    :from_index, :to_index, :granularity
  ) do
    # The country's primary currency (e.g. "USD" for "US"). Falls back to the
    # uppercased country code if the country isn't in the supported map —
    # callers can still render *some* unit rather than crashing.
    def country_currency_label
      require_relative "supported"
      Supported.currency_for_country(country) || country.to_s.upcase
    end
  end

  # CPI-based inflation adjustment for the {Supported::COUNTRIES} list.
  module Inflation
    module_function

    # Adjust `amount` from date `from` to date `to` using country CPI.
    #
    # Dates accept "YYYY" or "YYYY-MM".
    #
    # @param amount  [Numeric]
    # @param from    [String] source date ("YYYY" or "YYYY-MM")
    # @param to      [String] target date ("YYYY" or "YYYY-MM")
    # @param country [String] country code (see {Supported::COUNTRIES})
    # @return [InflationResult]
    # @raise [UnsupportedCountry] if `country` is not supported
    # @raise [DataNotFound]       if no CPI data covers the requested period
    def adjust(amount:, from:, to:, country:)
      lookup = CpiLookup.new(DataLoader.load_cpi(country))
      from_point = lookup.at(from)
      to_point   = lookup.at(to)

      ratio = to_point.value.to_f / from_point.value
      InflationResult.new(
        amount: amount.to_f * ratio,
        original_amount: amount.to_f,
        from: from,
        to: to,
        country: country.to_s.upcase,
        from_index: from_point.value,
        to_index: to_point.value,
        granularity: merge_granularity(from_point.granularity, to_point.granularity)
      )
    end

    # Inflation rate as decimal (e.g. 0.42 = 42%).
    #
    # @param from    [String]
    # @param to      [String]
    # @param country [String]
    # @return [Float] decimal rate (positive means inflation, negative deflation)
    def rate(from:, to:, country:)
      result = adjust(amount: 1.0, from: from, to: to, country: country)
      result.amount - 1.0
    end

    # If either end fell back to annual_from_monthly_avg, propagate that label;
    # else if either is annual, propagate :annual; else :monthly.
    def merge_granularity(a, b)
      return :annual_from_monthly_avg if a == :annual_from_monthly_avg || b == :annual_from_monthly_avg
      return :annual if a == :annual || b == :annual

      :monthly
    end
  end
end
