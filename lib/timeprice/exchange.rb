# frozen_string_literal: true

require "date"
require_relative "errors"
require_relative "data_loader"

module Timeprice
  ExchangeResult = Data.define(
    :amount, :original_amount, :from, :to, :date, :effective_date, :rate
  )

  module Exchange
    BASE = "USD"
    MAX_FALLBACK_DAYS = 7

    module_function

    # Convert `amount` from currency `from` to currency `to` on `date`.
    # date: "YYYY-MM-DD".
    def convert(amount:, from:, to:, date:)
      from = from.to_s.upcase
      to   = to.to_s.upcase
      raise UnsupportedCurrency, from unless SUPPORTED_CURRENCIES.include?(from)
      raise UnsupportedCurrency, to   unless SUPPORTED_CURRENCIES.include?(to)
      d = parse_date(date)

      rate, eff_date = resolve_rate(from, to, d)
      ExchangeResult.new(
        amount: amount.to_f * rate,
        original_amount: amount.to_f,
        from: from,
        to: to,
        date: d.to_s,
        effective_date: eff_date.to_s,
        rate: rate
      )
    end

    # Returns [rate (Float), effective_date (Date)].
    # Handles:
    #   - identity (from == to)
    #   - direct lookup of USD-base rate
    #   - inverse (foreign → USD)
    #   - triangulation through USD (both legs must resolve to SAME effective date)
    def resolve_rate(from, to, d)
      return [1.0, d] if from == to

      if from == BASE
        rate, eff = lookup_usd_base(to, d)
        [rate, eff]
      elsif to == BASE
        rate, eff = lookup_usd_base(from, d)
        [1.0 / rate, eff]
      else
        # Triangulation: from → USD → to, both legs at the same effective date.
        usd_to_from, eff_a = lookup_usd_base(from, d)
        usd_to_to,   eff_b = lookup_usd_base(to,   d)
        if eff_a != eff_b
          raise DataNotFound,
                "FX triangulation date mismatch for #{from}->#{to} on #{d}: " \
                "USD->#{from} resolved #{eff_a}, USD->#{to} resolved #{eff_b}"
        end
        [usd_to_to / usd_to_from, eff_a]
      end
    end

    # Walk back up to MAX_FALLBACK_DAYS to find a rate.
    # Returns [rate, effective_date].
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
        return [rate.to_f, candidate]
      end
      raise DataNotFound, "No FX rate for USD->#{currency} on or before #{d}"
    end

    def parse_date(date)
      case date
      when Date then date
      when String
        unless date.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          raise ArgumentError, "Invalid date format: #{date.inspect} (use YYYY-MM-DD)"
        end
        Date.parse(date)
      else
        raise ArgumentError, "Invalid date: #{date.inspect}"
      end
    end
  end
end
