# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__)) unless $LOAD_PATH.include?(File.expand_path("../lib", __dir__))
require "timeprice"

module Timeprice
  module Forecast
    # Holdout-based MAPE backtest for every supported country. The summary
    # is stashed on the module so RSpec can introspect it after the task runs.
    module Backtest
      class << self
        attr_accessor :last_summary
      end

      module_function

      HORIZONS_YEARS = [1, 3, 5].freeze
      WINDOW_YEARS   = 10

      def run!
        summary = {}
        Timeprice::Supported.countries.each do |country|
          data   = Timeprice::DataLoader.load_cpi(country)
          series = Forecast::CpiForecaster.pick_series(data)
          next if series.size < 24

          summary[country] = mape_for(series)
        end
        Backtest.last_summary = summary
        print_summary(summary)
      end

      # Returns { mape_1y: 0.012, mape_3y: 0.034, mape_5y: 0.061 } for the series.
      # For each horizon Y, treats the value Y years before the latest known
      # date as the "actual" we'd hope to predict using only data older than
      # that anchor.
      def mape_for(series)
        anchor_key  = series.keys.max_by { |k| Cagr.parse(k) }
        anchor_date = Cagr.parse(anchor_key)

        HORIZONS_YEARS.each_with_object({}) do |years, acc|
          truncate_date = Cagr.shift_years(anchor_date, -years)
          truncate_key  = truncate_date.strftime(anchor_key.length == 4 ? "%Y" : "%Y-%m")
          next unless series[truncate_key]

          truncated = series.select { |k, _| Cagr.parse(k) <= Cagr.parse(truncate_key) }
          predicted = project_from_series(truncated, anchor_key)
          actual    = series[anchor_key].to_f
          acc[:"mape_#{years}y"] = ((predicted - actual).abs / actual)
        end
      end

      # Direct CAGR projection from an already-truncated series, bypassing
      # DataLoader entirely.
      def project_from_series(series, target_key)
        last_key   = series.keys.max_by { |k| Cagr.parse(k) }
        last_value = series[last_key].to_f
        stats      = Cagr.compute(series: series, last_date: last_key, window_years: WINDOW_YEARS)

        months    = months_between(last_key, target_key)
        years_fwd = months / 12.0
        last_value * ((1.0 + stats[:cagr])**years_fwd)
      end

      def months_between(from_key, to_key)
        f = Cagr.parse(from_key)
        t = Cagr.parse(to_key)
        ((t.year - f.year) * 12) + (t.month - f.month)
      end

      def print_summary(summary)
        puts ""
        puts "Forecast backtest (CPI, trailing-#{WINDOW_YEARS}y CAGR, MAPE)"
        puts "country  +1y     +3y     +5y"
        summary.sort.each do |country, h|
          row = HORIZONS_YEARS.map do |y|
            h[:"mape_#{y}y"] ? format("%.2f%%", h[:"mape_#{y}y"] * 100) : "  -  "
          end
          puts format("%-8s %s", country, row.join(" "))
        end
        puts ""
      end
    end
  end
end

namespace :forecast do
  desc "Backtest CPI forecasts against the bundled holdout (1y / 3y / 5y MAPE)"
  task :backtest do
    Timeprice::Forecast::Backtest.run!
  end
end
