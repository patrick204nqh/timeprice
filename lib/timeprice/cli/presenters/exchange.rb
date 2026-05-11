# frozen_string_literal: true

require_relative "../formatting"

module Timeprice
  class CLI < Thor
    module Presenters
      # Renders an ExchangeResult for the CLI in text and JSON formats.
      class Exchange
        include Formatting

        def initialize(result)
          @result = result
        end

        def json_hash
          @result.to_h.merge(
            amount: round_money(@result.amount, @result.to),
            original_amount: round_money(@result.original_amount, @result.from),
            rate: @result.rate.to_f.round(6)
          )
        end

        def text_lines
          [
            "#{fmt_money(@result.amount, @result.to)} #{@result.to}  on #{@result.date}",
            format("  %s %s -> %s %s",
                   fmt_money(@result.original_amount, @result.from), @result.from,
                   fmt_money(@result.amount, @result.to), @result.to),
            "  #{rate_line}",
          ]
        end

        private

        def rate_line
          line = "rate #{fmt_rate(@result.rate)}"
          return line unless @result.effective_date && @result.effective_date != @result.date

          "#{line} from #{@result.effective_date} (fallback)"
        end
      end
    end
  end
end
