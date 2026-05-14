# frozen_string_literal: true

require_relative "errors"
require_relative "supported"
require_relative "point"
require_relative "inflation"
require_relative "exchange"
require_relative "granularity"

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
    module_function

    # Compare an amount across two (currency, date) points.
    #
    # @param amount [Numeric]
    # @param from   [Timeprice::Point, Array(String, String)] source point;
    #   accepts a {Point} or a 2-tuple like `["USD", "2010"]` or `["USD", "2010-06"]`
    # @param to     [Timeprice::Point, Array(String, String)] destination point
    # @return [CompareResult]
    # @raise [UnsupportedCurrency] if either currency is not in {Supported.currencies}
    def run(amount:, from:, to:)
      from_point, to_point, to_country = resolve_points(from, to)

      # Step 1: convert at source date into destination currency.
      fx_result = Exchange.convert(
        amount: amount,
        from: from_point.currency,
        to: to_point.currency,
        date: from_point.fx_anchor_date
      )
      converted = fx_result.amount

      # Step 2: inflate that destination-currency amount from source date to
      # destination date using destination-country CPI.
      infl = Inflation.adjust(
        amount: converted,
        from: from_point.date.to_s,
        to: to_point.date.to_s,
        country: to_country
      )

      CompareResult.new(
        amount: infl.amount,
        original_amount: amount.to_f,
        from_currency: from_point.currency,
        from_date: from_point.date.to_s,
        to_currency: to_point.currency,
        to_date: to_point.date.to_s,
        country: to_country,
        fx_rate: fx_result.rate,
        cpi_ratio: infl.to_index.to_f / infl.from_index,
        converted_amount: converted,
        granularity: Granularity.merge(fx_result.granularity, infl.granularity)
      )
    end

    # Coerce both points and resolve to_country.
    def resolve_points(from, to)
      from_point = Point.coerce(from)
      to_point   = Point.coerce(to)
      fail UnsupportedCurrency, from_point.currency unless Supported.country_for_currency(from_point.currency)

      to_country = Supported.country_for_currency(to_point.currency)
      fail UnsupportedCurrency, to_point.currency unless to_country

      [from_point, to_point, to_country]
    end
  end
end
