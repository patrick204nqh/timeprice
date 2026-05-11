# frozen_string_literal: true

require "thor"
require "json"
require_relative "../timeprice"

module Timeprice
  class CLI < Thor
    class_option :json, type: :boolean, default: false, desc: "Output result as JSON"

    def self.exit_on_failure?
      true
    end

    desc "inflation AMOUNT", "Adjust AMOUNT for inflation between two dates"
    method_option :from, type: :string, required: true, desc: "Source date (YYYY or YYYY-MM)"
    method_option :to,   type: :string, required: true, desc: "Target date (YYYY or YYYY-MM)"
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

    desc "fx AMOUNT FROM_CURRENCY TO_CURRENCY", "Convert AMOUNT between currencies on a given date"
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

    desc "sources", "List bundled data sources, licenses, attribution, and coverage"
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
      def with_error_handling
        yield
      rescue Timeprice::Error => e
        warn "Error: #{e.message}"
        exit 1
      rescue ArgumentError => e
        # Bad numeric/date format from Float() or library parsers — treat as user error.
        warn "Error: #{e.message}"
        exit 1
      end

      # Accepts "1995 USD" or "USD 1995" — order-agnostic.
      # Returns [currency, year_string] tuple matching Timeprice.compare's API.
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

      def emit_inflation(result)
        if options[:json]
          say JSON.generate(result.to_h)
        else
          say format(
            "%.2f %s in %s is %.2f %s in %s (%s, granularity: %s)",
            result.original_amount, result.country_currency_label,
            result.from, result.amount, result.country_currency_label,
            result.to, result.country, result.granularity
          )
        end
      end

      def emit_exchange(result)
        if options[:json]
          say JSON.generate(result.to_h)
        else
          line = format(
            "%.2f %s on %s = %.2f %s (rate: %.4f)",
            result.original_amount, result.from, result.date,
            result.amount, result.to, result.rate
          )
          if result.effective_date && result.effective_date != result.date
            line += " (effective date: #{result.effective_date} — fallback)"
          end
          say line
        end
      end

      def emit_compare(result)
        if options[:json]
          say JSON.generate(result.to_h)
        else
          say format(
            "%.2f %s in %s -> %.2f %s in %s",
            result.original_amount, result.from_currency, result.from_date,
            result.amount, result.to_currency, result.to_date
          )
          say format(
            "  steps: convert at %s (fx rate %.6f) -> %.4f %s, then inflate in %s (cpi ratio %.6f, granularity: %s)",
            result.from_date, result.fx_rate, result.converted_amount,
            result.to_currency, result.country, result.cpi_ratio, result.granularity
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
