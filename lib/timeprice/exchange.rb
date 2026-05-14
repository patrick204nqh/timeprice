# frozen_string_literal: true

require "date"
require_relative "errors"
require_relative "data_loader"
require_relative "supported"
require_relative "granularity"
require_relative "date"

module Timeprice
  ExchangeResult = Data.define(
    :amount, :original_amount, :from, :to, :date, :effective_date, :rate, :granularity
  )

  # Historical FX conversion using bundled per-year USD-base rate files.
  # Handles identity (USD→USD), direct lookup, inverse, and triangulation
  # through USD. Weekend/holiday dates fall back up to {MAX_FALLBACK_DAYS}
  # days to the nearest prior trading day.
  module Exchange
    BASE = "USD"
    MAX_FALLBACK_DAYS = 7

    module_function

    # Convert `amount` from currency `from` to currency `to` on `date`.
    #
    # @param amount [Numeric]
    # @param from   [String] ISO 4217 source currency
    # @param to     [String] ISO 4217 destination currency
    # @param date   [String, Date] date as "YYYY-MM-DD" or a Date instance
    # @return [ExchangeResult]
    # @raise [UnsupportedCurrency] if `from` or `to` is not supported
    # @raise [DataNotFound]        if no FX point exists within {MAX_FALLBACK_DAYS}
    def convert(amount:, from:, to:, date:)
      from = from.to_s.upcase
      to   = to.to_s.upcase
      fail UnsupportedCurrency, from unless Supported.currency?(from)
      fail UnsupportedCurrency, to   unless Supported.currency?(to)

      d = parse_date(date)

      rate, eff_date, granularity = resolve_rate(from, to, d)
      ExchangeResult.new(
        amount: amount.to_f * rate,
        original_amount: amount.to_f,
        from: from,
        to: to,
        date: d.to_s,
        effective_date: eff_date.to_s,
        rate: rate,
        granularity: granularity
      )
    end

    # Returns [rate (Float), effective_date (Date), granularity (Symbol)].
    # Granularity is :daily when the rate came from a per-date entry, :annual
    # when it came from the per-year `annual` fallback block. Triangulation
    # merges both legs via Granularity.merge (worst-precision-wins).
    # Handles:
    #   - identity (from == to)
    #   - direct lookup of USD-base rate
    #   - inverse (foreign → USD)
    #   - triangulation through USD (both legs must resolve to SAME effective date)
    def resolve_rate(from, to, d)
      return [1.0, d, Granularity::DAILY] if from == to

      if from == BASE
        lookup_usd_base(to, d)
      elsif to == BASE
        rate, eff, gran = lookup_usd_base(from, d)
        [1.0 / rate, eff, gran]
      else
        # Triangulation: from → USD → to, both legs at the same effective date.
        usd_to_from, eff_a, gran_a = lookup_usd_base(from, d)
        usd_to_to,   eff_b, gran_b = lookup_usd_base(to,   d)
        if eff_a != eff_b
          fail DataNotFound,
               "FX triangulation date mismatch for #{from}->#{to} on #{d}: " \
               "USD->#{from} resolved #{eff_a}, USD->#{to} resolved #{eff_b}"
        end
        [usd_to_to / usd_to_from, eff_a, Granularity.merge(gran_a, gran_b)]
      end
    end

    # Walk back up to MAX_FALLBACK_DAYS to find a daily rate; if none, fall
    # back to data/fx/usd/_annual.json (the single source of annual FX truth).
    # Returns [rate, effective_date, granularity].
    def lookup_usd_base(currency, d)
      (0..MAX_FALLBACK_DAYS).each do |offset|
        candidate = d - offset
        year_data =
          begin
            DataLoader.load_fx_year(candidate.year)
          rescue DataNotFound
            next
          end
        rates_for_day = year_data.dig("rates", candidate.to_s)
        next unless rates_for_day

        rate = rates_for_day[currency]
        next unless rate

        return [rate.to_f, candidate, Granularity::DAILY]
      end

      annual_rate = annual_fallback(currency, d.year)
      return [annual_rate, d, Granularity::ANNUAL] if annual_rate

      fail DataNotFound, "No FX rate for USD->#{currency} on or before #{d}"
    end

    # Consult data/fx/usd/_annual.json. Returns Float or nil.
    def annual_fallback(currency, year)
      fallback = DataLoader.load_fx_annual_fallback
      return nil unless fallback

      fallback.dig("annual", year.to_s, currency)&.to_f
    end

    def parse_date(date)
      case date
      when ::Date
        date
      when Timeprice::Date
        require_daily!(date)
        ::Date.new(date.year, date.month, date.day)
      when String
        parsed = Timeprice::Date.coerce(date)
        require_daily!(parsed)
        ::Date.new(parsed.year, parsed.month, parsed.day)
      else
        fail ArgumentError, "Invalid date: #{date.inspect}"
      end
    rescue ::Date::Error
      raise ArgumentError, "Invalid date: #{date.inspect} is not a real calendar date"
    end

    def require_daily!(date)
      return if date.granularity == :daily

      fail ArgumentError, "Invalid date: Exchange needs YYYY-MM-DD, got #{date}"
    end
  end
end
