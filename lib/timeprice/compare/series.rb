# frozen_string_literal: true

require_relative "../inflation"
require_relative "../exchange"
require_relative "../forecast/cpi_forecaster"
require_relative "../forecast/cagr"
require_relative "../cpi_lookup"
require_relative "../data_loader"
require_relative "../point"
require_relative "../supported"

module Timeprice
  module Compare
    # Annual sample points for the result-card chart. Composes the same FX
    # leg as {Compare.run} and a year-by-year measured-or-forecast CPI ratio
    # for the destination country.
    #
    # Each point is `{ date: "YYYY-01", amount:, measured: }`. Forecast
    # points additionally carry `:low` and `:high` for the ±1σ band.
    #
    # @api private
    module Series
      module_function

      DEFAULT_AMOUNT = 100.0

      def for(from:, to:, forecast: false, amount: DEFAULT_AMOUNT)
        ctx = build_context(from: from, to: to, amount: amount, forecast: forecast)
        (ctx[:from_year]..ctx[:to_year]).map { |y| point_for(y, ctx) }
      end

      def build_context(from:, to:, amount:, forecast:)
        from_point, to_point, to_country = coerce_points(from, to)
        data = DataLoader.load_cpi(to_country)
        last_key, last_cpi = last_known(data)
        last_year = Forecast::Cagr.parse(last_key).year

        {
          source_in_dest: source_amount_in_dest(amount, from_point, to_point),
          source_cpi: CpiLookup.new(data).at(from_point.date.to_s).value.to_f,
          lookup: CpiLookup.new(data),
          last_year: last_year,
          last_cpi: last_cpi,
          from_year: Forecast::Cagr.parse(from_point.date.to_s).year,
          to_year: Forecast::Cagr.parse(to_point.date.to_s).year,
          stats: forecast_stats(data, last_key, forecast, to_point, last_year),
        }
      end

      def coerce_points(from, to)
        from_point = Point.coerce(from)
        to_point   = Point.coerce(to)
        to_country = Supported.country_for_currency(to_point.currency)
        fail UnsupportedCurrency, to_point.currency unless to_country

        [from_point, to_point, to_country]
      end

      def source_amount_in_dest(amount, from_point, to_point)
        Exchange.convert(
          amount: amount, from: from_point.currency,
          to: to_point.currency, date: from_point.fx_anchor_date
        ).amount
      end

      def last_known(data)
        annual_or_monthly = Forecast::CpiForecaster.pick_series(data)
        last_key = annual_or_monthly.keys.max_by { |k| Forecast::Cagr.parse(k) }
        [last_key, annual_or_monthly[last_key].to_f]
      end

      def forecast_stats(data, last_key, forecast, to_point, last_year)
        return nil unless forecast && Forecast::Cagr.parse(to_point.date.to_s).year > last_year

        Forecast::Cagr.compute(
          series: Forecast::CpiForecaster.pick_series(data),
          last_date: last_key,
          window_years: Forecast::CpiForecaster::DEFAULT_WINDOW_YEARS
        )
      end

      def point_for(year, ctx)
        if year <= ctx[:last_year]
          measured_point(y: year, lookup: ctx[:lookup],
                         source_in_dest: ctx[:source_in_dest], source_cpi: ctx[:source_cpi])
        else
          forecast_point(y: year, last_year: ctx[:last_year], last_cpi: ctx[:last_cpi],
                         source_in_dest: ctx[:source_in_dest], source_cpi: ctx[:source_cpi],
                         stats: ctx[:stats])
        end
      end

      def measured_point(y:, lookup:, source_in_dest:, source_cpi:)
        cpi_y = lookup.at(y.to_s).value.to_f
        { date: "#{y}-01", amount: source_in_dest * (cpi_y / source_cpi), measured: true }
      rescue DataNotFound
        nil
      end

      def forecast_point(y:, last_year:, last_cpi:, source_in_dest:, source_cpi:, stats:)
        yrs = y - last_year
        mid  = last_cpi * ((1.0 + stats[:cagr])**yrs)
        low  = last_cpi * ((1.0 + stats[:cagr] - stats[:sigma_yoy])**yrs)
        high = last_cpi * ((1.0 + stats[:cagr] + stats[:sigma_yoy])**yrs)
        {
          date: "#{y}-01",
          amount: source_in_dest * (mid / source_cpi),
          low: source_in_dest * (low / source_cpi),
          high: source_in_dest * (high / source_cpi),
          measured: false,
        }
      end
    end

    # @see Series.for
    def self.series_for(**)
      Series.for(**).compact
    end
  end
end
