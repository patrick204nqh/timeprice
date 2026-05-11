# frozen_string_literal: true

require "thor"
require "json"
require_relative "../timeprice"
require_relative "cli/formatting"

module Timeprice
  class CLI < Thor
    include Formatting

    # Thor 1.5 ships a built-in `tree` command on every subclass. Strip it
    # from this subclass — it's an internal debugging aid that leaks into
    # our help output. all_commands inherits from the base Thor class, so
    # filter it on read.
    def self.all_commands
      super.except("tree")
    end

    class_option :json, type: :boolean, default: false, desc: "Output result as JSON"

    # Return false so Thor::Error propagates to our wrapper in `start`, where
    # we prettify the message and add a `See: timeprice help COMMAND` hint.
    def self.exit_on_failure?
      false
    end

    KNOWN_COMMANDS = %w[inflation fx compare sources version].freeze

    # Top-level help lists command names + descriptions only — matching git,
    # gh, cargo. Arg signatures live in per-command help (`timeprice help fx`).
    HELP_ROWS = [
      ["inflation", "Inflation-adjust an amount between two dates"],
      ["fx",        "Convert an amount between currencies on a date"],
      ["compare",   "Combine FX + inflation across (year, currency) points"],
      ["sources",   "List bundled data sources and coverage"],
      ["version",   "Print the installed timeprice version"],
    ].freeze

    # Pass debug: true so Thor re-raises Thor::Error (including option-parse
    # failures) instead of printing its own message and silently continuing
    # when exit_on_failure? is false. We catch and format ourselves.
    def self.start(given_args = ARGV, config = {})
      super(given_args, config.merge(debug: true))
    rescue Thor::Error => e
      warn "Error: #{prettify_thor_message(e.message)}"
      cmd = given_args.first
      warn "  See: timeprice help #{cmd}" if KNOWN_COMMANDS.include?(cmd)
      exit 1
    end

    def self.prettify_thor_message(msg)
      msg
        .sub(/\ANo value provided for required options /, "missing required options: ")
        .gsub("'", "")
    end

    # Thor's API dictates the positional boolean signature — keyword arg
    # would break the override.
    def self.help(shell, subcommand = false) # rubocop:disable Style/OptionalBooleanParameter
      return super if subcommand

      shell.say "timeprice — offline historical inflation & FX for Ruby"
      shell.say ""
      shell.say "Commands:"
      width = HELP_ROWS.map { |usage, _| usage.length }.max
      HELP_ROWS.each do |usage, desc|
        shell.say format("  %-#{width}s  %s", usage, desc)
      end
      shell.say ""
      shell.say "Global options:"
      shell.say "  --json   Output result as JSON"
      shell.say ""
      shell.say "Run `timeprice help COMMAND` for usage and options."
    end

    desc "inflation AMOUNT", "Inflation-adjust an amount between two dates"
    method_option :from,    type: :string, required: true, desc: "Source date (YYYY or YYYY-MM)"
    method_option :to,      type: :string, required: true, desc: "Target date (YYYY or YYYY-MM)"
    method_option :country, type: :string, required: true, desc: "Country code (US, UK, EU, JP, VN)"
    def inflation(amount)
      with_error_handling do
        result = Timeprice.inflation(
          amount: parse_amount(amount),
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
          amount: parse_amount(amount),
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
          amount: parse_amount(amount),
          from: from_tuple,
          to: to_tuple
        )
        emit_compare(result)
      end
    end

    desc "sources", "List bundled data sources and coverage"
    method_option :verbose, type: :boolean, default: false, aliases: "-v",
                            desc: "Include license URLs and full attribution"
    def sources
      list = Timeprice::Sources.list
      if options[:json]
        say JSON.generate(list)
      elsif options[:verbose]
        emit_sources_verbose(list)
      else
        emit_sources_table(list)
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
        warn "Error: #{e.message}"
        exit 1
      end

      def parse_amount(raw)
        Float(raw)
      rescue ArgumentError, TypeError
        raise ArgumentError, "AMOUNT must be a number, got #{raw.inspect}"
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

      def emit_sources_table(list)
        rows = list.map do |s|
          [s[:id].to_s, short_source_name(s[:name]), s[:license].to_s, s[:coverage].to_s]
        end
        headers = %w[ID SOURCE LICENSE COVERAGE]
        widths = headers.each_with_index.map do |h, i|
          [h.length, *rows.map { |r| r[i].length }].max
        end
        say format("  %-#{widths[0]}s  %-#{widths[1]}s  %-#{widths[2]}s  %s", *headers)
        rows.each do |r|
          say format("  %-#{widths[0]}s  %-#{widths[1]}s  %-#{widths[2]}s  %s", *r)
        end
        say ""
        say "Run `timeprice sources --verbose` for license URLs and full attribution."
      end

      def emit_sources_verbose(list)
        list.each do |s|
          say s[:name].to_s
          say "  id:           #{s[:id]}"
          say "  license:      #{s[:license]}"
          say "  license_url:  #{s[:license_url]}"
          say "  attribution:  #{s[:attribution]}"
          say "  coverage:     #{s[:coverage]}"
          say ""
        end
      end

      MAX_SOURCE_NAME = 60

      # Cap the source-name column width. Truncation is last resort — the full
      # name (with series code) is preserved in `--verbose` output.
      def short_source_name(name)
        s = name.to_s
        return s if s.length <= MAX_SOURCE_NAME

        "#{s[0, MAX_SOURCE_NAME - 1]}…"
      end

      def emit_inflation(result)
        ccy = result.country_currency_label
        options[:json] ? say(JSON.generate(inflation_json(result, ccy))) : emit_inflation_text(result, ccy)
      end

      def inflation_json(result, ccy)
        result.to_h.merge(
          amount: round_money(result.amount, ccy),
          original_amount: round_money(result.original_amount, ccy)
        )
      end

      def emit_inflation_text(result, ccy)
        say "#{fmt_money(result.amount, ccy)} #{ccy}  in #{result.to}"
        say format("  %s %s (%s) -> %s %s (%s)",
                   fmt_money(result.original_amount, ccy), ccy, result.from,
                   fmt_money(result.amount, ccy), ccy, result.to)
        say "  #{result.country} · #{result.granularity} CPI"
      end

      def emit_exchange(result)
        options[:json] ? say(JSON.generate(exchange_json(result))) : emit_exchange_text(result)
      end

      def exchange_json(result)
        result.to_h.merge(
          amount: round_money(result.amount, result.to),
          original_amount: round_money(result.original_amount, result.from),
          rate: result.rate.to_f.round(6)
        )
      end

      def emit_exchange_text(result)
        say "#{fmt_money(result.amount, result.to)} #{result.to}  on #{result.date}"
        say format("  %s %s -> %s %s",
                   fmt_money(result.original_amount, result.from), result.from,
                   fmt_money(result.amount, result.to), result.to)
        say "  #{rate_line(result)}"
      end

      def rate_line(result)
        line = "rate #{fmt_rate(result.rate)}"
        return line unless result.effective_date && result.effective_date != result.date

        "#{line} from #{result.effective_date} (fallback)"
      end

      def emit_compare(result)
        options[:json] ? say(JSON.generate(compare_json(result))) : emit_compare_text(result)
      end

      def compare_json(result)
        result.to_h.merge(
          amount: round_money(result.amount, result.to_currency),
          original_amount: round_money(result.original_amount, result.from_currency),
          converted_amount: round_money(result.converted_amount, result.to_currency),
          fx_rate: result.fx_rate.to_f.round(6),
          cpi_ratio: result.cpi_ratio.to_f.round(6)
        )
      end

      # Headline + left-to-right chain so the FX + CPI composition reads naturally.
      def emit_compare_text(result)
        final = "#{fmt_money(result.amount, result.to_currency)} #{result.to_currency}"
        original = "#{fmt_money(result.original_amount, result.from_currency)} #{result.from_currency}"
        converted = "#{fmt_money(result.converted_amount, result.to_currency)} #{result.to_currency}"
        step1 = "fx @ #{fmt_rate(result.fx_rate)}"
        step2 = "inflate x#{format("%.4f", result.cpi_ratio)} #{result.country}"
        width = [step1.length, step2.length].max
        say "#{final}  in #{result.to_date}"
        say "  #{original} (#{result.from_date})"
        say format("    -> %-#{width}s -> %s (%s)", step1, converted, result.from_date)
        say format("    -> %-#{width}s -> %s (%s, %s)", step2, final, result.to_date, result.granularity)
      end
    end
  end
end
