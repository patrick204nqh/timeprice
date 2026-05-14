# frozen_string_literal: true

require_relative "errors"

module Timeprice
  # Raised when a user-supplied date string can't be parsed into a
  # {Timeprice::Date} value.
  class InvalidDate < Error; end

  # Immutable value object representing "a date at some granularity": a
  # year, a year+month, a year+quarter, or a full calendar day. Used as
  # the canonical input shape for the public API (`Timeprice.inflation`,
  # `Timeprice.exchange`, `Timeprice.compare`) — strings are accepted for
  # convenience and coerced via {.coerce} at the boundary.
  # rubocop:disable Lint/ConstantDefinitionInBlock
  Date = Data.define(:year, :month, :quarter, :day) do
    ANNUAL_RE    = /\A(\d{4})\z/
    MONTHLY_RE   = /\A(\d{4})-(\d{2})\z/
    QUARTERLY_RE = /\A(\d{4})-Q([1-4])\z/i
    DAILY_RE     = /\A(\d{4})-(\d{2})-(\d{2})\z/

    def self.parse(str)
      case str.to_s
      when DAILY_RE
        new(year: ::Regexp.last_match(1).to_i, month: ::Regexp.last_match(2).to_i,
            quarter: nil, day: ::Regexp.last_match(3).to_i)
      when QUARTERLY_RE
        new(year: ::Regexp.last_match(1).to_i, month: nil,
            quarter: ::Regexp.last_match(2).to_i, day: nil)
      when MONTHLY_RE
        new(year: ::Regexp.last_match(1).to_i, month: ::Regexp.last_match(2).to_i,
            quarter: nil, day: nil)
      when ANNUAL_RE
        new(year: ::Regexp.last_match(1).to_i, month: nil, quarter: nil, day: nil)
      else
        raise InvalidDate, "Cannot parse #{str.inspect} as a Timeprice::Date"
      end
    end

    def self.coerce(input)
      input.is_a?(self) ? input : parse(input)
    end

    def granularity
      return :daily     if day
      return :monthly   if month
      return :quarterly if quarter

      :annual
    end

    def to_s
      case granularity
      when :daily     then format("%04d-%02d-%02d", year, month, day)
      when :monthly   then format("%04d-%02d", year, month)
      when :quarterly then format("%04d-Q%d", year, quarter)
      else format("%04d", year)
      end
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock
end
