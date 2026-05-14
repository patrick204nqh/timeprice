# frozen_string_literal: true

require_relative "namespace"

require_relative "_common"
require_relative "fx_year_file"

# Fetches USD-based FX rates from Frankfurter (ECB).
# Splits output by year into data/fx/usd/<year>.json.
#
# Notes:
#   - Frankfurter supports EUR/GBP/JPY/AUD/CAD/KRW/CNY back to 1999-01-04.
#   - Frankfurter does NOT support VND (handled via World Bank annual) or
#     RUB (publication stopped after the ECB suspended RUB reference rates
#     in March 2022 — see tools/data_pipeline/imf.rb for the RUB FX fallback).
module Tools
  module DataPipeline
    module Frankfurter
      BASE         = "USD"
      SYMBOLS      = %w[EUR GBP JPY AUD CAD KRW CNY].freeze
      START_DATE   = Date.new(1999, 1, 4)
      END_DATE     = Date.today - 1 # yesterday
      SOURCE_LABEL = "Frankfurter (ECB) — daily reference rates"

      module_function

      def fetch_range(start_date, end_date)
        url = "https://api.frankfurter.dev/v1/#{start_date}..#{end_date}" \
              "?base=#{BASE}&symbols=#{SYMBOLS.join(",")}"
        Tools::DataPipeline.http_json(url)["rates"] || {}
      end

      def run
        start_d = START_DATE
        end_d   = END_DATE
        total_points = 0
        total_new    = 0
        years_touched = []

        # Pull in 1-year chunks to keep responses small.
        cursor = start_d
        while cursor <= end_d
          chunk_end = [Date.new(cursor.year, 12, 31), end_d].min
          rates = fetch_range(cursor, chunk_end)
          # Group by year
          by_year = Hash.new { |h, k| h[k] = {} }
          rates.each do |date_str, currencies|
            year = date_str[0, 4].to_i
            # validate
            currencies.each_value do |v|
              fail "bad rate at #{date_str}" unless v.is_a?(Numeric) && v.positive? && v < 1e9
            end
            by_year[year][date_str] = currencies
          end
          by_year.each do |year, year_rates|
            path = File.join(Tools::DataPipeline::DATA_ROOT, "fx", "usd", "#{year}.json")
            existing_rates = (Tools::DataPipeline.read_json_if_exists(path) || {})["rates"] || {}
            new_count = year_rates.keys.count { |d| !existing_rates.key?(d) }
            total_new += new_count
            total_points += year_rates.size

            Tools::DataPipeline::FxYearFile.new(year).write_daily(
              rates_by_date: year_rates,
              provider_id: "frankfurter",
              source_label: SOURCE_LABEL
            )
            years_touched << year unless years_touched.include?(year)
          end
          cursor = Date.new(cursor.year + 1, 1, 1)
        end

        year_range = years_touched.minmax
        Tools::DataPipeline.log "Frankfurter: #{total_points} (date,rate) updates across #{years_touched.size} year files (#{year_range.first}..#{year_range.last}), #{total_new} new since last run."
      end
    end
  end
end

Tools::DataPipeline::Frankfurter.run if __FILE__ == $PROGRAM_NAME
