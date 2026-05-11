# frozen_string_literal: true

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
    # Coerce input into a Point. Accepts:
    #   - {Point} (returned as-is)
    #   - 2-element Array of [currency, date] in either order
    #
    # @param input [Point, Array]
    # @return [Point]
    # @raise [ArgumentError] if shape can't be recognised
    def self.coerce(input)
      return input if input.is_a?(Point)

      unless input.is_a?(Array) && input.size == 2
        raise ArgumentError, "Expected Timeprice::Point or [currency, date] tuple, got #{input.inspect}"
      end

      a, b = input.map(&:to_s)
      currency = [a, b].find { |s| s.match?(/\A[A-Za-z]{3}\z/) }
      date     = [a, b].find { |s| s.match?(/\A\d{4}(-\d{2}(-\d{2})?)?\z/) }

      if currency.nil? || date.nil?
        raise ArgumentError,
              "Could not detect currency + date in #{input.inspect} " \
              "(expected a 3-letter currency and a YYYY[-MM[-DD]] date)"
      end

      new(currency: currency.upcase, date: date)
    end
  end
end
