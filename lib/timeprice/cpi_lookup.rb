# frozen_string_literal: true

require_relative "errors"
require_relative "granularity"

module Timeprice
  # CpiPoint pairs a CPI index value with the granularity of how it was
  # resolved. See {Granularity} for the full set of possible tags.
  CpiPoint = Data.define(:value, :granularity)

  # Resolves CPI keys ("YYYY", "YYYY-MM", or "YYYY-Qn") to a CpiPoint against
  # a single country's parsed CPI data hash. Knowing the JSON shape ("monthly"
  # / "quarterly" / "annual" string keys) is isolated here — Inflation just
  # asks for points.
  class CpiLookup
    QUARTER_RE = /\A(\d{4})-Q([1-4])\z/

    def initialize(data)
      @data = data
      @monthly   = data.dig("series", "monthly")   || {}
      @quarterly = data.dig("series", "quarterly") || {}
      @annual    = data.dig("series", "annual")    || {}
    end

    # @param key [String] "YYYY", "YYYY-MM", or "YYYY-Qn"
    # @return [CpiPoint]
    # @raise [DataNotFound] if no CPI value covers `key`
    # @raise [ArgumentError] on malformed `key`
    def at(key)
      key = key.to_s
      case key
      when QUARTER_RE        then quarterly_or_fallbacks(key)
      when /\A\d{4}-\d{2}\z/ then monthly_or_fallbacks(key)
      when /\A\d{4}\z/       then annual_or_derived(key)
      else raise ArgumentError, "Invalid date format: #{key.inspect} (use YYYY, YYYY-MM, or YYYY-Qn)"
      end
    end

    private

    def monthly_or_fallbacks(month_key)
      return CpiPoint.new(value: @monthly[month_key], granularity: Granularity::MONTHLY) if @monthly.key?(month_key)

      year, month = month_key.split("-").map(&:to_i)
      qkey = format("%04d-Q%d", year, ((month - 1) / 3) + 1)
      if @quarterly.key?(qkey)
        return CpiPoint.new(value: @quarterly[qkey], granularity: Granularity::MONTHLY_FROM_QUARTERLY_FALLBACK)
      end

      year_key = month_key[0, 4]
      raise DataNotFound, missing_message(month_key) unless @annual.key?(year_key)

      CpiPoint.new(value: @annual[year_key], granularity: Granularity::MONTHLY_FROM_ANNUAL_FALLBACK)
    end

    def quarterly_or_fallbacks(quarter_key)
      if @quarterly.key?(quarter_key)
        return CpiPoint.new(value: @quarterly[quarter_key],
                            granularity: Granularity::QUARTERLY)
      end

      year_int, q = quarter_key.match(QUARTER_RE).captures.map(&:to_i)
      first_month = ((q - 1) * 3) + 1
      last_month  = q * 3
      months = (first_month..last_month).map { |m| format("%04d-%02d", year_int, m) }
                                        .map { |k| @monthly[k] }
                                        .compact
      if months.size == 3
        return CpiPoint.new(value: months.sum.to_f / 3,
                            granularity: Granularity::QUARTERLY_FROM_MONTHLY_AVG)
      end

      year = quarter_key[0, 4]
      raise DataNotFound, missing_message(quarter_key) unless @annual.key?(year)

      CpiPoint.new(value: @annual[year], granularity: Granularity::QUARTERLY_FROM_ANNUAL_FALLBACK)
    end

    def annual_or_derived(year)
      return CpiPoint.new(value: @annual[year], granularity: Granularity::ANNUAL) if @annual.key?(year)

      months   = @monthly.select { |k, _| k.start_with?("#{year}-") }
      quarters = @quarterly.select { |k, _| k.start_with?("#{year}-Q") }

      # Prefer complete-period averages over partials, and within each, prefer
      # monthly resolution. Partial tags distinguish biased estimates (e.g.
      # only Jan-Feb populated) from a true full-year mean.
      return average(months, 12, Granularity::ANNUAL_FROM_MONTHLY_AVG) if months.size == 12
      return average(quarters, 4, Granularity::ANNUAL_FROM_QUARTERLY_AVG) if quarters.size == 4
      return average(months, months.size, Granularity::ANNUAL_FROM_PARTIAL_MONTHS) if months.any?
      return average(quarters, quarters.size, Granularity::ANNUAL_FROM_PARTIAL_QUARTERS) if quarters.any?

      raise DataNotFound, missing_message(year)
    end

    def average(series, divisor, granularity)
      CpiPoint.new(value: series.values.sum.to_f / divisor, granularity: granularity)
    end

    def missing_message(key)
      country = @data["country"]
      ranges = []
      ranges << "monthly #{@monthly.keys.min}..#{@monthly.keys.max}" if @monthly.any?
      ranges << "quarterly #{@quarterly.keys.min}..#{@quarterly.keys.max}" if @quarterly.any?
      ranges << "annual #{@annual.keys.min}..#{@annual.keys.max}" if @annual.any?
      hint = ranges.empty? ? "" : " (supported: #{ranges.join(", ")})"
      "No CPI data for #{key.inspect} in #{country}#{hint}"
    end
  end
end
