# frozen_string_literal: true

require "thor"
require "json"
require_relative "../timeprice"
require_relative "cli/presenters/inflation"
require_relative "cli/presenters/exchange"
require_relative "cli/presenters/compare"
require_relative "cli/presenters/sources"

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
    method_option :from,    type: :string, required: true, desc: "Source date (YYYY, YYYY-MM, or YYYY-Qn)"
    method_option :to,      type: :string, required: true, desc: "Target date (YYYY, YYYY-MM, or YYYY-Qn)"
    method_option :country, type: :string, required: true, desc: "Country code (US, UK, EU, JP, VN, AU, CA, KR, CN, RU)"
    def inflation(amount)
      with_error_handling do
        result = Timeprice.inflation(
          amount: parse_amount(amount),
          from: options[:from],
          to: options[:to],
          country: options[:country]
        )
        render Presenters::Inflation.new(result)
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
        render Presenters::Exchange.new(result)
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
        render Presenters::Compare.new(result)
      end
    end

    desc "sources", "List bundled data sources and coverage"
    method_option :verbose, type: :boolean, default: false, aliases: "-v",
                            desc: "Include license URLs and full attribution"
    def sources
      render Presenters::Sources.new(Timeprice::Sources.list, verbose: options[:verbose])
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
      def render(presenter)
        if options[:json]
          say JSON.generate(presenter.json_hash)
        else
          presenter.text_lines.each { |line| say line }
        end
      end

      def with_error_handling
        yield
      rescue Timeprice::Error, ArgumentError => e
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

        Point.coerce(parts)
      rescue ArgumentError => e
        raise if e.message.start_with?(label)

        raise ArgumentError, "#{label}: #{e.message}"
      end
    end
  end
end
