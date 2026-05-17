# frozen_string_literal: true

require "date"

module Timeprice
  module Forecast
    # Pure math: trailing CAGR and σ of year-over-year changes.
    #
    # The series is a hash mapping date strings (`"YYYY"` or `"YYYY-MM"`) to
    # numeric values. The trailing window is anchored on `last_date` and
    # extends `window_years` backward. CAGR is the annualized geometric
    # return between the first and last samples in the window. Sigma is the
    # sample stdev of 1-year-spaced returns within the window.
    #
    # No I/O, no DataLoader. Pure function — call from anywhere.
    #
    # @api private
    module Cagr
      module_function

      # @param series       [Hash{String => Numeric}]
      # @param last_date    [String] anchor ("YYYY" or "YYYY-MM")
      # @param window_years [Integer]
      # @return [Hash] { cagr: Float, sigma_yoy: Float, window_start: String,
      #                  window_end: String, samples: Integer }
      def compute(series:, last_date:, window_years:)
        end_date   = parse(last_date)
        start_date = shift_years(end_date, -window_years)

        sorted = series
                 .select { |k, _| within?(k, start_date, end_date) }
                 .sort_by { |k, _| parse(k) }

        fail ArgumentError, "need at least 2 points in window" if sorted.size < 2

        first_v = sorted.first.last.to_f
        last_v  = sorted.last.last.to_f
        cagr = ((last_v / first_v)**(1.0 / window_years)) - 1.0

        sigma = stdev_of_yoy(sorted)

        {
          cagr: cagr,
          sigma_yoy: sigma,
          window_start: sorted.first.first,
          window_end: sorted.last.first,
          samples: sorted.size,
        }
      end

      def parse(s)
        s = s.to_s
        return ::Date.new(s.to_i, 1, 1) if s.length == 4

        y, m = s.split("-").map(&:to_i)
        ::Date.new(y, m, 1)
      end

      def shift_years(date, years)
        ::Date.new(date.year + years, date.month, 1)
      end

      def within?(key, start_date, end_date)
        d = parse(key)
        d.between?(start_date, end_date)
      end

      # Stdev of 1-year-spaced log returns (annualized YoY changes).
      # Returns 0.0 when fewer than 2 paired samples exist.
      def stdev_of_yoy(sorted)
        by_date = sorted.to_h
        returns = sorted.filter_map do |key, value|
          prior_key = shift_years(parse(key), -1).strftime(key.length == 4 ? "%Y" : "%Y-%m")
          prior = by_date[prior_key]
          next unless prior&.positive?

          (value.to_f / prior) - 1.0
        end
        return 0.0 if returns.size < 2

        mean = returns.sum / returns.size
        variance = returns.sum { |r| (r - mean)**2 } / (returns.size - 1)
        Math.sqrt(variance)
      end
    end
  end
end
