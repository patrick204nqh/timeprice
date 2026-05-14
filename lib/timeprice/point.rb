# frozen_string_literal: true

require_relative "date"

module Timeprice
  # A (currency, date) pair used as input to {Timeprice.compare}.
  #
  # The library accepts either a Point or a 2-element array. Arrays may be
  # ordered either way (`["USD", "2010"]` or `["2010", "USD"]`) — the year
  # and currency are detected by shape. This mirrors what the CLI already
  # tolerates and removes the only "which slot is which?" footgun.
  #
  # @example
  #   Timeprice::Point.new(currency: "USD", date: "2010")
  #   Timeprice::Point.coerce(["USD", "2010"])
  #   Timeprice::Point.coerce(["2010", "USD"])
  Point = Data.define(:currency, :date) do
    # Canonical constructor. Accepts a stdlib-string or Timeprice::Date
    # for the date argument; stores the canonical string form.
    def self.parse(currency, date)
      new(currency: currency.to_s.upcase, date: Timeprice::Date.coerce(date).to_s)
    end

    # Coerce input into a Point. Accepts:
    #   - {Point} (returned as-is)
    #   - 2-element Array of [currency, date] in either order
    #
    # @param input [Point, Array]
    # @return [Point]
    # @raise [ArgumentError] if shape can't be recognised
    def self.coerce(input)
      case input
      in Point
        input
      in [_, _]
        a, b = input.map(&:to_s)
        currency = [a, b].find { |s| s.match?(/\A[A-Za-z]{3}\z/) }
        date     = [a, b].find { |s| s.match?(/\A\d{4}(-\d{2}(-\d{2})?)?\z/) }
        fail ArgumentError, malformed_pair_message(input) if currency.nil? || date.nil?

        new(currency: currency.upcase, date: date)
      else
        fail ArgumentError, "Expected Timeprice::Point or [currency, date] tuple, got #{input.inspect}"
      end
    end

    def self.malformed_pair_message(input)
      "Could not detect currency + date in #{input.inspect} " \
        "(expected a 3-letter currency and a YYYY[-MM[-DD]] date)"
    end

    # Resolve `date` to a full YYYY-MM-DD for FX lookup.
    #
    # Coarser grains anchor to a representative day:
    #   - "YYYY"    → mid-year (YYYY-06-30)
    #   - "YYYY-MM" → mid-month (YYYY-MM-15)
    #   - "YYYY-MM-DD" → passes through
    #
    # @return [String]
    # @raise [ArgumentError] if `date` doesn't match any supported shape
    def fx_anchor_date
      case date.to_s
      when /\A\d{4}\z/         then "#{date}-06-30"
      when /\A\d{4}-\d{2}\z/   then "#{date}-15"
      when /\A\d{4}-\d{2}-\d{2}\z/ then date.to_s
      else fail ArgumentError, "Invalid date for Point: #{date.inspect}"
      end
    end
  end
end
