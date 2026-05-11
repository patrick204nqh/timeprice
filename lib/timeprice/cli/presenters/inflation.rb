# frozen_string_literal: true

require_relative "../formatting"
require_relative "../../granularity"

module Timeprice
  class CLI < Thor
    module Presenters
      # Renders an InflationResult for the CLI in text and JSON formats.
      class Inflation
        include Formatting

        def initialize(result)
          @result = result
          @ccy = result.country_currency_label
        end

        def json_hash
          @result.to_h.merge(
            amount: round_money(@result.amount, @ccy),
            original_amount: round_money(@result.original_amount, @ccy)
          )
        end

        def text_lines
          [
            "#{fmt_money(@result.amount, @ccy)} #{@ccy}  in #{@result.to}",
            format("  %s %s (%s) -> %s %s (%s)",
                   fmt_money(@result.original_amount, @ccy), @ccy, @result.from,
                   fmt_money(@result.amount, @ccy), @ccy, @result.to),
            "  #{@result.country} · #{Granularity.humanize(@result.granularity)} CPI",
          ]
        end
      end
    end
  end
end
