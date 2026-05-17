# frozen_string_literal: true

require_relative "../forecast"
require_relative "../data_loader"
require_relative "../errors"
require_relative "cagr"

module Timeprice
  module Forecast
    # Project a country's CPI index forward from the last bundled data point.
    #
    # @api private
    module CpiForecaster
      module_function

      DEFAULT_WINDOW_YEARS = 10
      HORIZON_CAP_YEARS    = 5

      # @param country      [String]
      # @param target       [String] "YYYY" or "YYYY-MM"
      # @param window_years [Integer]
      # @return [Forecast::Result]
      # @raise [DataNotFound] if the CPI series has no usable monthly or annual data
      def project(country:, target:, window_years: DEFAULT_WINDOW_YEARS)
        series = load_series(country)
        last_key, last_value = last_entry(series)
        warnings = build_warnings(series, last_key, target, window_years)
        stats = Cagr.compute(series: series, last_date: last_key, window_years: window_years)
        build_result(last_key, last_value, target, { window_years: window_years, stats: stats, warnings: warnings })
      end

      # Prefer monthly when present; fall back to annual.
      def pick_series(data)
        monthly = data.dig("series", "monthly") || {}
        return monthly unless monthly.empty?

        data.dig("series", "annual") || {}
      end

      def months_between(from_key, to_key)
        f = Cagr.parse(from_key)
        t = Cagr.parse(to_key)
        ((t.year - f.year) * 12) + (t.month - f.month)
      end

      def load_series(country)
        data = DataLoader.load_cpi(country.to_s.upcase)
        series = pick_series(data)
        fail DataNotFound, "no CPI series for #{country}" if series.empty?

        series
      end

      def last_entry(series)
        last_key = series.keys.max_by { |k| Cagr.parse(k) }
        [last_key, series[last_key].to_f]
      end

      def build_warnings(series, last_key, target, window_years)
        warnings = []
        earliest = series.keys.map { |k| Cagr.parse(k).year }.min
        warnings << "insufficient_window" if Cagr.parse(last_key).year - window_years < earliest
        horizon_months = months_between(last_key, target)
        warnings << "horizon_exceeds_cap" if horizon_months > HORIZON_CAP_YEARS * 12
        warnings.uniq
      end

      def build_result(last_key, last_value, target, opts)
        window_years = opts[:window_years]
        stats = opts[:stats]
        warnings = opts[:warnings]
        horizon_months = months_between(last_key, target)
        years_forward = horizon_months / 12.0
        cagr = stats[:cagr]
        sigma = stats[:sigma_yoy]

        Forecast::Result.new(
          value: last_value * ((1.0 + cagr)**years_forward),
          low: last_value * ((1.0 + cagr - sigma)**years_forward),
          high: last_value * ((1.0 + cagr + sigma)**years_forward),
          projection_method: "cagr_trailing",
          window_years: window_years,
          sigma_pct: sigma,
          last_known_date: last_key,
          target_date: target,
          horizon_months: horizon_months,
          basis_kind: :cpi,
          warnings: warnings
        )
      end
    end
  end
end
