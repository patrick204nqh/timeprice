# frozen_string_literal: true

require "thor"
require "json"
require_relative "../timeprice"

module Timeprice
  class CLI < Thor
    # Thor 1.5 ships a built-in `tree` command on every subclass. Strip it
    # from this subclass — it's an internal debugging aid that leaks into
    # our help output. all_commands inherits from the base Thor class, so
    # filter it on read.
    def self.all_commands
      super.except("tree")
    end

    class_option :json, type: :boolean, default: false, desc: "Output result as JSON"

    def self.exit_on_failure?
      true
    end

    desc "inflation AMOUNT", "Inflation-adjust an amount between two dates"
    method_option :from,    type: :string, required: true, desc: "Source date (YYYY or YYYY-MM)"
    method_option :to,      type: :string, required: true, desc: "Target date (YYYY or YYYY-MM)"
    method_option :country, type: :string, required: true, desc: "Country code (US, UK, EU, JP, VN)"
    def inflation(amount)
      with_error_handling do
        result = Timeprice.inflation(
          amount: Float(amount),
          from: options[:from],
          to: options[:to],
          country: options[:country]
        )
        emit_inflation(result)
      end
    end

    desc "fx AMOUNT FROM TO", "Convert an amount between currencies on a date"
    method_option :date, type: :string, required: true, desc: "Date (YYYY-MM-DD)"
    def fx(amount, from_currency, to_currency)
      with_error_handling do
        result = Timeprice.exchange(
          amount: Float(amount),
          from: from_currency,
          to: to_currency,
          date: options[:date]
        )
        emit_exchange(result)
      end
    end

    desc "compare AMOUNT", "Combine FX + inflation across two (year, currency) points"
    method_option :from, type: :string, required: true, desc: "Source as \"YEAR CURRENCY\" or \"CURRENCY YEAR\""
    method_option :to,   type: :string, required: true, desc: "Target as \"YEAR CURRENCY\" or \"CURRENCY YEAR\""
    def compare(amount)
      with_error_handling do
        from_tuple = parse_compare_token(options[:from], label: "--from")
        to_tuple   = parse_compare_token(options[:to],   label: "--to")
        result = Timeprice.compare(
          amount: Float(amount),
          from: from_tuple,
          to: to_tuple
        )
        emit_compare(result)
      end
    end

    desc "sources", "List bundled data sources and coverage"
    def sources
      list = Timeprice::Sources.list
      if options[:json]
        say JSON.generate(list)
      else
        list.each do |s|
          say "#{s[:name]}"
          say "  id:           #{s[:id]}"
          say "  license:      #{s[:license]}"
          say "  license_url:  #{s[:license_url]}"
          say "  attribution:  #{s[:attribution]}"
          say "  coverage:     #{s[:coverage]}"
          say ""
        end
      end
    end

    desc "version", "Print the installed timeprice version"
    def version
      if options[:json]
        say JSON.generate({ version: Timeprice::VERSION, repo: "patrick204nqh/timeprice" })
      else
        say "timeprice #{Timeprice::VERSION} — patrick204nqh/timeprice"
      end
    end

    no_commands do
      # Currencies with no minor unit — render whole numbers, no decimals.
      ZERO_DECIMAL_CURRENCIES = %w[JPY VND KRW IDR HUF CLP].freeze

      def with_error_handling
        yield
      rescue Timeprice::Error => e
        warn "Error: #{e.message}"
        exit 1
      rescue ArgumentError => e
        warn "Error: #{e.message}"
        exit 1
      end

      def parse_compare_token(token, label:)
        raise ArgumentError, "#{label} is required" if token.nil? || token.strip.empty?
        parts = token.strip.split(/\s+/)
        unless parts.size == 2
          raise ArgumentError,
                "#{label} must be \"YEAR CURRENCY\" or \"CURRENCY YEAR\", got #{token.inspect}"
        end
        year = parts.find { |p| p.match?(/\A\d{4}\z/) }
        currency = parts.find { |p| p.match?(/\A[A-Za-z]{3}\z/) }
        if year.nil? || currency.nil?
          raise ArgumentError,
                "#{label} must contain a 4-digit year and a 3-letter currency code, got #{token.inspect}"
        end
        [currency.upcase, year]
      end

      def fmt_money(amount, currency)
        decimals = ZERO_DECIMAL_CURRENCIES.include?(currency.to_s.upcase) ? 0 : 2
        format("%.#{decimals}f", amount)
      end

      def fmt_rate(rate)
        abs = rate.to_f.abs
        decimals = if abs >= 1000 then 0
                   elsif abs >= 100 then 2
                   elsif abs >= 10  then 3
                   else 4
                   end
        format("%.#{decimals}f", rate)
      end

      # Granularity is loud noise on the happy path. Only surface it when the
      # answer actually used annual data — that's where users want a heads-up.
      def granularity_suffix(granularity)
        return "" if granularity == :monthly
        " (granularity: #{granularity})"
      end

      def emit_inflation(result)
        if options[:json]
          say JSON.generate(result.to_h)
        else
          ccy = result.country_currency_label
          say format(
            "%s %s in %s is %s %s in %s [%s]%s",
            fmt_money(result.original_amount, ccy), ccy, result.from,
            fmt_money(result.amount, ccy), ccy, result.to,
            result.country, granularity_suffix(result.granularity)
          )
        end
      end

      def emit_exchange(result)
        if options[:json]
          say JSON.generate(result.to_h)
        else
          line = format(
            "%s %s on %s = %s %s (rate: %s)",
            fmt_money(result.original_amount, result.from), result.from, result.date,
            fmt_money(result.amount, result.to), result.to, fmt_rate(result.rate)
          )
          if result.effective_date && result.effective_date != result.date
            line += " [effective: #{result.effective_date}, fallback]"
          end
          say line
        end
      end

      def emit_compare(result)
        if options[:json]
          say JSON.generate(result.to_h)
        else
          say format(
            "%s %s in %s -> %s %s in %s",
            fmt_money(result.original_amount, result.from_currency), result.from_currency, result.from_date,
            fmt_money(result.amount, result.to_currency), result.to_currency, result.to_date
          )
          say format(
            "  steps: %s %s -> %s %s (fx %s on %s), then inflate in %s x%.4f%s",
            fmt_money(result.original_amount, result.from_currency), result.from_currency,
            fmt_money(result.converted_amount, result.to_currency), result.to_currency,
            fmt_rate(result.fx_rate), result.from_date,
            result.country, result.cpi_ratio, granularity_suffix(result.granularity)
          )
        end
      end
    end
  end
end

# Tiny shim so we can include currency context in the inflation line without
# bloating the value object — the result doesn't carry currency, only country.
module Timeprice
  class InflationResult
    COUNTRY_TO_CURRENCY = {
      "US" => "USD", "UK" => "GBP", "EU" => "EUR", "JP" => "JPY", "VN" => "VND"
    }.freeze

    def country_currency_label
      COUNTRY_TO_CURRENCY[country.to_s.upcase] || country.to_s.upcase
    end
  end
end
