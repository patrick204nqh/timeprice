# frozen_string_literal: true

require_relative "../forecast"
require_relative "../data_loader"
require_relative "../errors"
require_relative "cagr"

module Timeprice
  module Forecast
    # Project a currency-pair FX rate forward using the same trailing-CAGR
    # mechanism as CpiForecaster, but with FX-appropriate defaults: 5-year
    # window, 2-year horizon cap.
    #
    # The annual series is reconstructed by reading each bundled year file
    # and pulling the year-end (or annual-average where present) rate. The
    # daily granularity that {Exchange} works with is too noisy to anchor a
    # multi-year extrapolation — annualizing first is the whole point.
    #
    # @api private
    module FxForecaster
      module_function

      DEFAULT_WINDOW_YEARS = 5
      HORIZON_CAP_YEARS    = 2

      def project(from:, to:, target:, window_years: DEFAULT_WINDOW_YEARS)
        from = from.to_s.upcase
        to   = to.to_s.upcase

        series = load_annual_series(from, to)
        fail DataNotFound, "no FX series for #{from}->#{to}" if series.empty?

        last_key       = series.keys.max
        last_value     = series[last_key].to_f
        horizon_months = months_between(last_key, target)
        warnings       = []
        warnings << "horizon_exceeds_cap" if horizon_months > HORIZON_CAP_YEARS * 12

        stats = Cagr.compute(series: series, last_date: last_key, window_years: window_years)

        build_result(
          last_key: last_key, last_value: last_value,
          target: target, horizon_months: horizon_months,
          window_years: window_years, stats: stats, warnings: warnings
        )
      end

      # Build an annual {year_string => rate} series by reading each FX year
      # file. Prefers the `annual` block when present, otherwise averages
      # the daily `rates` map for that year. Returns {} if no year files
      # for `from`->`to` exist on disk.
      def load_annual_series(from, to)
        root = File.join(DataLoader.data_root, "fx")
        return {} unless File.directory?(root)

        years = Dir.children(root).filter_map do |f|
          Regexp.last_match(1).to_i if f =~ /\A(\d{4})\.json\z/
        end.sort
        years.each_with_object({}) do |year, acc|
          payload = DataLoader.load_fx(year)
          rate    = pick_year_rate(payload, from, to)
          acc[year.to_s] = rate if rate
        end
      end

      def pick_year_rate(payload, from, to)
        annual = payload.dig("annual", from, to)
        return annual.to_f if annual

        daily = payload.dig("rates", from, to)
        return nil unless daily.is_a?(Hash) && !daily.empty?

        values = daily.values.map(&:to_f)
        values.sum / values.size
      end

      def months_between(from_key, to_key)
        f = Cagr.parse(from_key)
        t = Cagr.parse(to_key)
        ((t.year - f.year) * 12) + (t.month - f.month)
      end

      def build_result(last_key:, last_value:, target:, horizon_months:, window_years:, stats:, warnings:)
        years_forward = horizon_months / 12.0
        value = last_value * ((1.0 + stats[:cagr])**years_forward)
        low   = last_value * ((1.0 + stats[:cagr] - stats[:sigma_yoy])**years_forward)
        high  = last_value * ((1.0 + stats[:cagr] + stats[:sigma_yoy])**years_forward)

        Forecast::Result.new(
          value: value, low: low, high: high,
          projection_method: "cagr_trailing",
          window_years: window_years,
          sigma_pct: stats[:sigma_yoy],
          last_known_date: last_key,
          target_date: target,
          horizon_months: horizon_months,
          basis_kind: :fx,
          warnings: warnings.uniq
        )
      end
    end
  end
end
