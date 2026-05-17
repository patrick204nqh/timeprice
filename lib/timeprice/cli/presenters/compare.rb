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
          base = @result.to_h.merge(
            amount: round_money(@result.amount, @result.to_currency),
            original_amount: round_money(@result.original_amount, @result.from_currency),
            converted_amount: round_money(@result.converted_amount, @result.to_currency),
            fx_rate: @result.fx_rate.to_f.round(6),
            cpi_ratio: @result.cpi_ratio.to_f.round(6)
          )
          if @result.forecast
            fc = @result.forecast
            base[:forecast] = fc.merge(
              low: round_money(fc[:low], @result.to_currency),
              high: round_money(fc[:high], @result.to_currency)
            )
          end
          base
        end

        # Headline + left-to-right chain so the FX + CPI composition reads naturally.
        def text_lines
          final     = "#{fmt_money(@result.amount, @result.to_currency)} #{@result.to_currency}"
          original  = "#{fmt_money(@result.original_amount, @result.from_currency)} #{@result.from_currency}"
          converted = "#{fmt_money(@result.converted_amount, @result.to_currency)} #{@result.to_currency}"
          step1     = "fx @ #{fmt_rate(@result.fx_rate)}"
          step2     = "inflate x#{format("%.4f", @result.cpi_ratio)} #{@result.country}"
          width     = [step1.length, step2.length].max
          headline = if @result.forecast
                       "#{final}  in #{@result.to_date}  (forecast)"
                     else
                       "#{final}  in #{@result.to_date}"
                     end
          lines = [
            headline,
            "  #{original} (#{@result.from_date})",
            format("    -> %-#{width}s -> %s (%s)", step1, converted, @result.from_date),
            format("    -> %-#{width}s -> %s (%s, %s)", step2, final, @result.to_date,
                   Granularity.humanize(@result.granularity)),
          ]
          @result.forecast ? lines + forecast_lines(final) : lines
        end

        private

        def forecast_lines(mid_str)
          fc       = @result.forecast
          low_str  = "#{fmt_money(fc[:low], @result.to_currency)} #{@result.to_currency}"
          high_str = "#{fmt_money(fc[:high], @result.to_currency)} #{@result.to_currency}"
          extra = [
            "",
            "  range     #{low_str}  —  #{mid_str}  —  #{high_str}",
            "            (low -1σ)        (most likely)      (high +1σ)",
            "",
            "  basis     trailing #{fc[:window_years]}y CAGR · last data #{fc[:last_known_date]}",
            "            sigma ±#{format("%.1f", fc[:sigma_pct] * 100)}%/yr · horizon +#{fc[:horizon_months]}mo",
          ]
          if fc[:warnings].include?("horizon_exceeds_cap")
            extra << "  caveat    forecasts past 5y are illustrative, not predictive"
          end
          extra
        end
      end
    end
  end
end
