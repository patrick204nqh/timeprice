# frozen_string_literal: true

module Timeprice
  class CLI < Thor
    # Number/currency formatting helpers shared by every CLI emitter.
    # Lives as a mixin (rather than a free-standing module function set) so
    # callers can use the helpers as plain methods inside `no_commands` blocks.
    module Formatting
      # Currencies with no minor unit — render whole numbers, no decimals.
      ZERO_DECIMAL_CURRENCIES = %w[JPY VND].freeze

      def fmt_money(amount, currency)
        with_commas(format("%.#{currency_decimals(currency)}f", amount))
      end

      # Two decimals once we're past the unit threshold; six decimals for
      # sub-unit rates so tiny rates (e.g. 0.000045) still carry signal.
      def fmt_rate(rate)
        decimals = rate.to_f.abs >= 1 ? 2 : 6
        with_commas(format("%.#{decimals}f", rate))
      end

      def currency_decimals(currency)
        ZERO_DECIMAL_CURRENCIES.include?(currency.to_s.upcase) ? 0 : 2
      end

      def round_money(amount, currency)
        amount.to_f.round(currency_decimals(currency))
      end

      def with_commas(num_str)
        sign = num_str.start_with?("-") ? "-" : ""
        whole, frac = num_str.sub(/\A-/, "").split(".", 2)
        whole = whole.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
        frac ? "#{sign}#{whole}.#{frac}" : "#{sign}#{whole}"
      end
    end
  end
end
