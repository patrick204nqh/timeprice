# frozen_string_literal: true

require_relative "base"

# US CPI-U series CUUR0000SA0 from the BLS Public API v2.
# No API key required for low volume. Pulls 10 years at a time (V2 limit
# without key is 10 years).
module Sources
  class BLS < Base
    SERIES_ID  = "CUUR0000SA0"
    START_YEAR = 1990

    configure(
      country_code: "us",
      country_label: "United States",
      source_label: "BLS CUUR0000SA0 (CPI-U, U.S. city average, all items)",
      default_base_year: "1982-1984=100",
      log_label: "BLS"
    )

    def fetch_chunk(start_year, end_year)
      body = { "seriesid" => [SERIES_ID], "startyear" => start_year.to_s, "endyear" => end_year.to_s }
      url  = "https://api.bls.gov/publicAPI/v2/timeseries/data/"
      json = Sources.http_json(url, method: :post, body: body)
      raise "BLS: #{json["status"]}: #{json["message"]}" unless json["status"] == "REQUEST_SUCCEEDED"

      json.dig("Results", "series", 0, "data") || []
    end

    def fetch
      end_year = Date.today.year
      monthly  = {}
      annual   = {}

      cursor = START_YEAR
      while cursor <= end_year
        chunk_end = [cursor + 9, end_year].min
        data = fetch_chunk(cursor, chunk_end)
        data.each do |entry|
          raw = entry["value"].to_s
          next if raw.empty? || raw == "-"

          val = begin
            Float(raw)
          rescue StandardError
            nil
          end
          next if val.nil? || !val.positive?

          year = entry["year"]
          period = entry["period"] # "M01".."M12" or "M13" (annual avg)
          if period == "M13"
            annual[year] = val
          elsif period.start_with?("M")
            month = period[1, 2]
            monthly["#{year}-#{month}"] = val
          end
        end
        cursor = chunk_end + 1
        sleep(1.0) # be polite to BLS rate limits
      end

      # Compute annual fallback from monthly averages where annual missing.
      monthly_by_year = monthly.group_by { |k, _v| k[0, 4] }
      monthly_by_year.each do |year, pairs|
        next if annual.key?(year)
        next unless pairs.size == 12

        avg = pairs.sum { |_k, v| v } / 12.0
        annual[year] = avg.round(3)
      end

      [monthly, annual]
    end
  end
end

Sources::BLS.run if __FILE__ == $PROGRAM_NAME
