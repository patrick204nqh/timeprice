# frozen_string_literal: true

require_relative "../formatting"
require_relative "../../granularity"

module Timeprice
  class CLI < Thor
    module Presenters
      # Renders a CompareResult for the CLI in text and JSON formats.
      class Compare
        include Formatting

        def initialize(result)
          @result = result
        end

        def json_hash
          @result.to_h.merge(
            amount: round_money(@result.amount, @result.to_currency),
            original_amount: round_money(@result.original_amount, @result.from_currency),
            converted_amount: round_money(@result.converted_amount, @result.to_currency),
            fx_rate: @result.fx_rate.to_f.round(6),
            cpi_ratio: @result.cpi_ratio.to_f.round(6)
          )
        end

        # Headline + left-to-right chain so the FX + CPI composition reads naturally.
        def text_lines
          final = "#{fmt_money(@result.amount, @result.to_currency)} #{@result.to_currency}"
          original = "#{fmt_money(@result.original_amount, @result.from_currency)} #{@result.from_currency}"
          converted = "#{fmt_money(@result.converted_amount, @result.to_currency)} #{@result.to_currency}"
          step1 = "fx @ #{fmt_rate(@result.fx_rate)}"
          step2 = "inflate x#{format("%.4f", @result.cpi_ratio)} #{@result.country}"
          width = [step1.length, step2.length].max
          [
            "#{final}  in #{@result.to_date}",
            "  #{original} (#{@result.from_date})",
            format("    -> %-#{width}s -> %s (%s)", step1, converted, @result.from_date),
            format("    -> %-#{width}s -> %s (%s, %s)", step2, final, @result.to_date,
                   Granularity.humanize(@result.granularity)),
          ]
        end
      end
    end
  end
end
