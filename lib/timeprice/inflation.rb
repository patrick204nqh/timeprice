# frozen_string_literal: true

require_relative "errors"
require_relative "data_loader"

module Timeprice
  # Value object returned by Inflation.adjust.
  #
  # granularity is one of:
  #   :monthly                  — both ends resolved on monthly data
  #   :annual                   — at least one end resolved on annual data
  #   :annual_from_monthly_avg  — at least one end was an annual request resolved
  #                               by averaging 12 months of monthly data
  InflationResult = Data.define(
    :amount, :original_amount, :from, :to, :country,
    :from_index, :to_index, :granularity
  )

  # CPI-based inflation adjustment for the {Supported::COUNTRIES} list.
  module Inflation
    module_function

    # Adjust `amount` from date `from` to date `to` using country CPI.
    #
    # Dates accept "YYYY" or "YYYY-MM".
    #
    # @param amount  [Numeric]
    # @param from    [String] source date ("YYYY" or "YYYY-MM")
    # @param to      [String] target date ("YYYY" or "YYYY-MM")
    # @param country [String] country code (see {Supported::COUNTRIES})
    # @return [InflationResult]
    # @raise [UnsupportedCountry] if `country` is not supported
    # @raise [DataNotFound]       if no CPI data covers the requested period
    def adjust(amount:, from:, to:, country:)
      data = DataLoader.load_cpi(country)
      from_index, from_gran = lookup_index(data, from)
      to_index,   to_gran   = lookup_index(data, to)

      ratio = to_index.to_f / from_index
      InflationResult.new(
        amount: amount.to_f * ratio,
        original_amount: amount.to_f,
        from: from,
        to: to,
        country: country.to_s.upcase,
        from_index: from_index,
        to_index: to_index,
        granularity: merge_granularity(from_gran, to_gran)
      )
    end

    # Inflation rate as decimal (e.g. 0.42 = 42%).
    #
    # @param from    [String]
    # @param to      [String]
    # @param country [String]
    # @return [Float] decimal rate (positive means inflation, negative deflation)
    def rate(from:, to:, country:)
      result = adjust(amount: 1.0, from: from, to: to, country: country)
      result.amount - 1.0
    end

    # Returns [index_value, granularity_symbol]
    def lookup_index(data, key)
      key = key.to_s
      monthly = data["monthly"] || {}
      annual  = data["annual"]  || {}

      case key
      when /\A\d{4}-\d{2}\z/
        if monthly.key?(key)
          [monthly[key], :monthly]
        else
          year = key[0, 4]
          raise DataNotFound, missing_cpi_message(key, data, monthly, annual) unless annual.key?(year)

          [annual[year], :annual]

        end
      when /\A\d{4}\z/
        if annual.key?(key)
          [annual[key], :annual]
        else
          months = monthly.select { |k, _| k.start_with?("#{key}-") }
          raise DataNotFound, missing_cpi_message(key, data, monthly, annual) if months.empty?

          avg = months.values.sum.to_f / months.size
          [avg, :annual_from_monthly_avg]
        end
      else
        raise ArgumentError, "Invalid date format: #{key.inspect} (use YYYY or YYYY-MM)"
      end
    end

    def missing_cpi_message(key, data, monthly, annual)
      country = data["country"]
      ranges = []
      if monthly.any?
        ks = monthly.keys.sort
        ranges << "monthly #{ks.first}..#{ks.last}"
      end
      if annual.any?
        ks = annual.keys.sort
        ranges << "annual #{ks.first}..#{ks.last}"
      end
      hint = ranges.empty? ? "" : " (supported: #{ranges.join(", ")})"
      "No CPI data for #{key.inspect} in #{country}#{hint}"
    end

    # If either end fell back to annual_from_monthly_avg, propagate that label;
    # else if either is annual, propagate :annual; else :monthly.
    def merge_granularity(a, b)
      return :annual_from_monthly_avg if a == :annual_from_monthly_avg || b == :annual_from_monthly_avg
      return :annual if a == :annual || b == :annual

      :monthly
    end
  end
end
