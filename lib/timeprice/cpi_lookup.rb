# frozen_string_literal: true

require_relative "errors"
require_relative "granularity"

module Timeprice
  # CpiPoint pairs a CPI index value with the granularity of how it was
  # resolved. See {Granularity} for the full set of possible tags.
  CpiPoint = Data.define(:value, :granularity)

  # Resolves CPI keys ("YYYY" or "YYYY-MM") to a CpiPoint against a single
  # country's parsed CPI data hash. Knowing the JSON shape ("monthly" /
  # "annual" string keys) is isolated here — Inflation just asks for points.
  class CpiLookup
    def initialize(data)
      @data = data
      @monthly = data.dig("series", "monthly") || {}
      @annual  = data.dig("series", "annual")  || {}
    end

    # @param key [String] "YYYY" or "YYYY-MM"
    # @return [CpiPoint]
    # @raise [DataNotFound] if no CPI value covers `key`
    # @raise [ArgumentError] on malformed `key`
    def at(key)
      key = key.to_s
      case key
      when /\A\d{4}-\d{2}\z/ then monthly_or_annual_fallback(key)
      when /\A\d{4}\z/       then annual_or_monthly_average(key)
      else raise ArgumentError, "Invalid date format: #{key.inspect} (use YYYY or YYYY-MM)"
      end
    end

    private

    def monthly_or_annual_fallback(month_key)
      return CpiPoint.new(value: @monthly[month_key], granularity: Granularity::MONTHLY) if @monthly.key?(month_key)

      year = month_key[0, 4]
      raise DataNotFound, missing_message(month_key) unless @annual.key?(year)

      CpiPoint.new(value: @annual[year], granularity: Granularity::MONTHLY_FROM_ANNUAL_FALLBACK)
    end

    def annual_or_monthly_average(year)
      return CpiPoint.new(value: @annual[year], granularity: Granularity::ANNUAL) if @annual.key?(year)

      months = @monthly.select { |k, _| k.start_with?("#{year}-") }
      raise DataNotFound, missing_message(year) if months.empty?

      avg = months.values.sum.to_f / months.size
      CpiPoint.new(value: avg, granularity: Granularity::ANNUAL_FROM_MONTHLY_AVG)
    end

    def missing_message(key)
      country = @data["country"]
      ranges = []
      ranges << "monthly #{@monthly.keys.min}..#{@monthly.keys.max}" if @monthly.any?
      ranges << "annual #{@annual.keys.min}..#{@annual.keys.max}" if @annual.any?
      hint = ranges.empty? ? "" : " (supported: #{ranges.join(", ")})"
      "No CPI data for #{key.inspect} in #{country}#{hint}"
    end
  end
end
