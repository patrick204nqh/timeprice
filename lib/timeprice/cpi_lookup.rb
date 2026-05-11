# frozen_string_literal: true

require_relative "errors"

module Timeprice
  # CpiPoint pairs a CPI index value with the granularity of how it was
  # resolved (monthly, annual, or annual derived by averaging 12 months).
  CpiPoint = Data.define(:value, :granularity)

  # Resolves CPI keys ("YYYY" or "YYYY-MM") to a CpiPoint against a single
  # country's parsed CPI data hash. Knowing the JSON shape ("monthly" /
  # "annual" string keys) is isolated here — Inflation just asks for points.
  class CpiLookup
    def initialize(data)
      @data = data
      @monthly = data["monthly"] || {}
      @annual  = data["annual"]  || {}
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
      return CpiPoint.new(value: @monthly[month_key], granularity: :monthly) if @monthly.key?(month_key)

      year = month_key[0, 4]
      raise DataNotFound, missing_message(month_key) unless @annual.key?(year)

      CpiPoint.new(value: @annual[year], granularity: :annual)
    end

    def annual_or_monthly_average(year)
      return CpiPoint.new(value: @annual[year], granularity: :annual) if @annual.key?(year)

      months = @monthly.select { |k, _| k.start_with?("#{year}-") }
      raise DataNotFound, missing_message(year) if months.empty?

      CpiPoint.new(value: months.values.sum.to_f / months.size, granularity: :annual_from_monthly_avg)
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
