# frozen_string_literal: true

require_relative "errors"
require_relative "inflation"
require_relative "exchange"

module Timeprice
  CompareResult = Data.define(
    :amount, :original_amount,
    :from_currency, :from_date,
    :to_currency, :to_date,
    :country, :fx_rate, :cpi_ratio,
    :converted_amount, :granularity
  )

  # Compare combines FX and inflation across two (currency, date) points.
  #
  # CONVENTION (critical): convert at SOURCE date first, then inflate in
  # destination currency. See README.md "Compare semantics" section.
  #
  # This preserves purchasing-power equivalence in the destination economy.
  # The naive alternative (inflate in source currency first, then convert at
  # destination date) double-counts source-country inflation because nominal
  # FX rates already absorb relative inflation between the two currencies.
  #
  # If a future refactor flips the order, the regression test in
  # spec/timeprice/compare_spec.rb will fail.
  module Compare
    # Map ISO currency → CPI country code.
    CURRENCY_TO_COUNTRY = {
      "USD" => "US",
      "GBP" => "UK",
      "EUR" => "EU",
      "JPY" => "JP",
      "VND" => "VN",
    }.freeze

    module_function

    # amount: Numeric
    # from:   [currency, date_or_year] e.g. ["USD", "2010"] or ["USD", "2010-06"]
    # to:     [currency, date_or_year]
    def run(amount:, from:, to:)
      from_currency, from_date = from
      to_currency,   to_date   = to
      from_currency = from_currency.to_s.upcase
      to_currency   = to_currency.to_s.upcase

      to_country = CURRENCY_TO_COUNTRY[to_currency] ||
                   (raise UnsupportedCurrency, to_currency)
      CURRENCY_TO_COUNTRY[from_currency] || (raise UnsupportedCurrency, from_currency)

      # Step 1: convert at source date into destination currency.
      fx_date = normalize_fx_date(from_date)
      fx_result = Exchange.convert(
        amount: amount,
        from: from_currency,
        to: to_currency,
        date: fx_date
      )
      converted = fx_result.amount

      # Step 2: inflate that destination-currency amount from source date to
      # destination date using destination-country CPI.
      infl = Inflation.adjust(
        amount: converted,
        from: from_date.to_s,
        to: to_date.to_s,
        country: to_country
      )

      CompareResult.new(
        amount: infl.amount,
        original_amount: amount.to_f,
        from_currency: from_currency,
        from_date: from_date.to_s,
        to_currency: to_currency,
        to_date: to_date.to_s,
        country: to_country,
        fx_rate: fx_result.rate,
        cpi_ratio: infl.to_index.to_f / infl.from_index,
        converted_amount: converted,
        granularity: infl.granularity
      )
    end

    # If the user gave a year like "2010", anchor FX to mid-year (2010-06-30).
    # If they gave "YYYY-MM", anchor to the 15th. Full dates pass through.
    def normalize_fx_date(date)
      s = date.to_s
      case s
      when /\A\d{4}\z/ then "#{s}-06-30"
      when /\A\d{4}-\d{2}\z/ then "#{s}-15"
      when /\A\d{4}-\d{2}-\d{2}\z/ then s
      else raise ArgumentError, "Invalid date for compare: #{date.inspect}"
      end
    end
  end
end
