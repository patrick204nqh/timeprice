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

        last_key       = series.keys.max_by { |k| Cagr.parse(k) }
        last_value     = series[last_key].to_f
        horizon_months = months_between(last_key, target)
        earliest_year  = series.keys.map { |k| Cagr.parse(k).year }.min
        warnings       = []
        warnings << "insufficient_window" if Cagr.parse(last_key).year - window_years < earliest_year
        warnings << "horizon_exceeds_cap" if horizon_months > HORIZON_CAP_YEARS * 12

        stats = Cagr.compute(series: series, last_date: last_key, window_years: window_years)

        build_result(
          last_key: last_key, last_value: last_value,
          target: target, horizon_months: horizon_months,
          window_years: window_years, stats: stats, warnings: warnings
        )
      end

      # Build an annual {year_string => rate} series by reading each FX year
      # file and computing a daily average for the requested currency pair.
      # Falls back to the _annual.json file for years where the daily file
      # does not cover the requested pair. Returns {} if no data is found.
      def load_annual_series(from, to)
        root = File.join(DataLoader.data_root, "fx", "usd")
        return {} unless File.directory?(root)

        fallback = DataLoader.load_fx_annual_fallback
        years = Dir.children(root).filter_map do |f|
          Regexp.last_match(1).to_i if f =~ /\A(\d{4})\.json\z/
        end.sort

        years.each_with_object({}) do |year, acc|
          rate = pick_year_rate(DataLoader.load_fx_year(year), from, to)
          rate ||= pick_annual_fallback_rate(fallback, year, from, to) if fallback
          acc[year.to_s] = rate if rate
        end
      end

      # Compute an annual average rate for +from+->+to+ from a year-file
      # payload. Year-file rates are stored as USD->currency daily rates.
      #
      #   from == "USD"  => average rates[date][to] across all dates
      #   to   == "USD"  => average rates[date][from], then invert
      #   else (cross)   => per-date to/from ratio, then average
      def pick_year_rate(payload, from, to)
        daily = payload["rates"]
        return nil unless daily.is_a?(Hash) && !daily.empty?

        if from == "USD"
          daily_avg(daily.values, to)
        elsif to == "USD"
          invert_avg(daily.values, from)
        else
          cross_avg(daily.values, from, to)
        end
      end

      # Extract an annual rate for +from+->+to+ from the _annual.json fallback.
      # Fallback stores USD->currency annual averages keyed by year string.
      def pick_annual_fallback_rate(fallback, year, from, to)
        ann = fallback.dig("annual", year.to_s)
        return nil unless ann.is_a?(Hash)

        if from == "USD"
          ann[to]&.to_f
        elsif to == "USD"
          invert_scalar(ann[from]&.to_f)
        else
          cross_scalar(ann[from]&.to_f, ann[to]&.to_f)
        end
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

      # --- private helpers ---

      # Average USD->+currency+ values across all day_rates hashes.
      def daily_avg(day_rates_list, currency)
        vals = day_rates_list.filter_map { |dr| dr[currency]&.to_f }
        return nil if vals.empty?

        vals.sum / vals.size
      end

      # Average USD->+currency+ then invert to get currency->USD.
      def invert_avg(day_rates_list, currency)
        mean = daily_avg(day_rates_list, currency)
        invert_scalar(mean)
      end

      # Average the per-day cross rate (USD->to / USD->from) for dates where
      # both currencies are present.
      def cross_avg(day_rates_list, from, to)
        pairs = day_rates_list.filter_map do |dr|
          usd_from = dr[from]&.to_f
          usd_to   = dr[to]&.to_f
          cross_scalar(usd_from, usd_to)
        end
        return nil if pairs.empty?

        pairs.sum / pairs.size
      end

      # Invert a single USD->X scalar to X->USD; nil if zero or nil.
      def invert_scalar(val)
        return nil unless val&.positive?

        1.0 / val
      end

      # Compute cross rate from two USD->X scalars; nil if either is nil/zero.
      def cross_scalar(usd_from, usd_to)
        return nil unless usd_from&.positive? && usd_to

        usd_to / usd_from
      end
    end
  end
end
