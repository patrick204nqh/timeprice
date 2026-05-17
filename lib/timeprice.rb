# frozen_string_literal: true

require_relative "timeprice/version"
require_relative "timeprice/errors"
require_relative "timeprice/schema"
require_relative "timeprice/date"
require_relative "timeprice/data_loader"
require_relative "timeprice/supported"
require_relative "timeprice/point"
require_relative "timeprice/inflation"
require_relative "timeprice/exchange"
require_relative "timeprice/compare"
require_relative "timeprice/forecast"
require_relative "timeprice/forecast/cagr"
require_relative "timeprice/forecast/cpi_forecaster"
require_relative "timeprice/forecast/fx_forecaster"
require_relative "timeprice/sources"
require_relative "timeprice/metadata"

# Offline historical inflation & FX for Ruby.
#
# Top-level module functions wrap the three core operations: inflation
# adjustment, currency exchange, and a combined "compare" that does both
# in the right order. Each returns an immutable `Data.define` value object.
#
# @example Inflation
#   Timeprice.inflation(amount: 100, from: "1990-01", to: "2024-01", country: "US")
# @example FX
#   Timeprice.exchange(amount: 100, from: "USD", to: "JPY", date: "2010-06-15")
# @example Compare
#   Timeprice.compare(amount: 100, from: ["USD", "2010"], to: ["VND", "2024"])
module Timeprice
  module_function

  # Inflation-adjust an amount between two dates using a country's CPI.
  #
  # @param amount  [Numeric] the original amount
  # @param from    [String]  source date as "YYYY" or "YYYY-MM"
  # @param to      [String]  target date as "YYYY" or "YYYY-MM"
  # @param country [String]  country code from {Supported.countries}
  # @return [InflationResult]
  # @raise [UnsupportedCountry] if `country` is not supported
  # @raise [DataNotFound]       if no CPI point covers `from` or `to`
  def inflation(amount:, from:, to:, country:)
    Inflation.adjust(amount: amount, from: from, to: to, country: country)
  end

  # Convert an amount between currencies on a specific date.
  #
  # @param amount [Numeric] the original amount
  # @param from   [String]  source currency (ISO 4217)
  # @param to     [String]  destination currency (ISO 4217)
  # @param date   [String]  date as "YYYY-MM-DD"
  # @return [ExchangeResult]
  # @raise [UnsupportedCurrency] if either currency is not supported
  # @raise [DataNotFound]        if no FX point exists within the fallback window
  def exchange(amount:, from:, to:, date:)
    Exchange.convert(amount: amount, from: from, to: to, date: date)
  end

  # Project a CPI index or FX rate forward past the last bundled data point.
  #
  # @param kind         [Symbol] :cpi or :fx
  # @param target       [String] target date as "YYYY" or "YYYY-MM"
  # @param country      [String] (only when kind: :cpi)
  # @param from         [String] (only when kind: :fx) source currency
  # @param to           [String] (only when kind: :fx) destination currency
  # @param window_years [Integer, nil] override default trailing window
  # @return [Forecast::Result]
  def forecast(kind:, target:, country: nil, from: nil, to: nil, window_years: nil)
    case kind
    when :cpi
      fail ArgumentError, "country: required for kind: :cpi" unless country

      opts = { country: country, target: target }
      opts[:window_years] = window_years if window_years
      Forecast::CpiForecaster.project(**opts)
    when :fx
      fail ArgumentError, "from:/to: required for kind: :fx" unless from && to

      opts = { from: from, to: to, target: target }
      opts[:window_years] = window_years if window_years
      Forecast::FxForecaster.project(**opts)
    else
      fail ArgumentError, "unknown forecast kind: #{kind.inspect} (expected :cpi or :fx)"
    end
  end

  # Compare an amount across two (currency, date) points: convert at the
  # source date, then inflate in the destination currency. See README.md
  # "Compare semantics" for why this order is correct.
  #
  # @param amount [Numeric]
  # @param from   [Point, Array(String, String)] source point
  # @param to     [Point, Array(String, String)] destination point
  # @return [CompareResult]
  def compare(amount:, from:, to:, forecast: false)
    Compare.run(amount: amount, from: from, to: to, forecast: forecast)
  end

  # Snapshot describing the bundled dataset: version, refresh date, country
  # list with CPI ranges, currency list with display names, and FX coverage.
  # Intended as the single source of truth for downstream UIs (the website
  # in particular) so dropdowns and date pickers never drift from the data.
  #
  # @return [Hash] frozen, JSON-serialisable
  def metadata
    Metadata.build
  end
end
