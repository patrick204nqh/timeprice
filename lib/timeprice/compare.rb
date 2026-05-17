# frozen_string_literal: true

require_relative "errors"
require_relative "supported"
require_relative "point"
require_relative "inflation"
require_relative "exchange"
require_relative "granularity"
require_relative "cpi_lookup"
require_relative "compare/series"

module Timeprice
  CompareResult = Data.define(
    :amount, :original_amount,
    :from_currency, :from_date,
    :to_currency, :to_date,
    :country, :fx_rate, :cpi_ratio,
    :converted_amount, :granularity,
    :forecast
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
  #
  # @api private
  # The supported public entry point is {Timeprice.compare}. Direct
  # references will move to `Timeprice::Internal::Compare` in a future
  # release.
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
    def run(amount:, from:, to:, forecast: false)
      from_point, to_point, to_country = resolve_points(from, to)

      if forecast && future_target?(to_point, to_country)
        return run_with_forecast(
          amount: amount, from_point: from_point, to_point: to_point, to_country: to_country
        )
      end

      fx_result = Exchange.convert(
        amount: amount, from: from_point.currency,
        to: to_point.currency, date: from_point.fx_anchor_date
      )

      if from_point.date == to_point.date
        return fx_only_result(
          amount: amount, from_point: from_point, to_point: to_point,
          to_country: to_country, fx_result: fx_result
        )
      end

      measured_result(
        amount: amount, from_point: from_point, to_point: to_point,
        to_country: to_country, fx_result: fx_result
      )
    end

    def measured_result(amount:, from_point:, to_point:, to_country:, fx_result:)
      infl = Inflation.adjust(
        amount: fx_result.amount,
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
        converted_amount: fx_result.amount,
        granularity: Granularity.merge(fx_result.granularity, infl.granularity),
        forecast: nil
      )
    end

    # Same-date branch: no time-elapsed inflation, so the FX leg alone is
    # the answer. Builds a CompareResult with cpi_ratio=1.0.
    def fx_only_result(amount:, from_point:, to_point:, to_country:, fx_result:)
      CompareResult.new(
        amount: fx_result.amount,
        original_amount: amount.to_f,
        from_currency: from_point.currency,
        from_date: from_point.date.to_s,
        to_currency: to_point.currency,
        to_date: to_point.date.to_s,
        country: to_country,
        fx_rate: fx_result.rate,
        cpi_ratio: 1.0,
        converted_amount: fx_result.amount,
        granularity: fx_result.granularity,
        forecast: nil
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

    # Returns true when to_point.date is past the destination country's last
    # bundled CPI date.
    def future_target?(to_point, to_country)
      data   = DataLoader.load_cpi(to_country)
      series = Forecast::CpiForecaster.pick_series(data)
      last   = series.keys.max_by { |k| Forecast::Cagr.parse(k) }
      Forecast::Cagr.parse(to_point.date.to_s) > Forecast::Cagr.parse(last)
    end

    def run_with_forecast(amount:, from_point:, to_point:, to_country:)
      fx_result = Exchange.convert(
        amount: amount, from: from_point.currency,
        to: to_point.currency, date: from_point.fx_anchor_date
      )
      cpi_fwd          = Forecast::CpiForecaster.project(country: to_country, target: to_point.date.to_s)
      source_cpi_value = source_index(to_country, from_point.date.to_s)
      inflation_ratio  = cpi_fwd.value / source_cpi_value

      CompareResult.new(
        amount: fx_result.amount * inflation_ratio,
        original_amount: amount.to_f,
        from_currency: from_point.currency, from_date: from_point.date.to_s,
        to_currency: to_point.currency,     to_date: to_point.date.to_s,
        country: to_country,
        fx_rate: fx_result.rate,
        cpi_ratio: inflation_ratio,
        converted_amount: fx_result.amount,
        granularity: :forecast,
        forecast: forecast_hash(cpi_fwd: cpi_fwd, converted: fx_result.amount, source_cpi: source_cpi_value)
      )
    end

    def forecast_hash(cpi_fwd:, converted:, source_cpi:)
      {
        basis_kind: cpi_fwd.basis_kind,
        projection_method: cpi_fwd.projection_method,
        window_years: cpi_fwd.window_years,
        sigma_pct: cpi_fwd.sigma_pct,
        last_known_date: cpi_fwd.last_known_date,
        horizon_months: cpi_fwd.horizon_months,
        low: converted * (cpi_fwd.low / source_cpi),
        high: converted * (cpi_fwd.high / source_cpi),
        warnings: cpi_fwd.warnings,
      }
    end

    # Resolve a measured CPI index for the source date (which must be in range).
    def source_index(country, date)
      CpiLookup.new(DataLoader.load_cpi(country)).at(date).value.to_f
    end
  end
end
