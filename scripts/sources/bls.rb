# frozen_string_literal: true

require_relative "_common"

# US CPI-U series CUUR0000SA0 from the BLS Public API v2.
# No API key required for low volume. Pulls 10 years at a time (V2 limit
# without key is 10 years).
module Sources
  module BLS
    SERIES_ID    = "CUUR0000SA0"
    SOURCE_LABEL = "BLS CUUR0000SA0 (CPI-U, U.S. city average, all items)"
    START_YEAR   = 1990

    module_function

    def fetch_chunk(start_year, end_year)
      body = { "seriesid" => [SERIES_ID], "startyear" => start_year.to_s, "endyear" => end_year.to_s }
      url  = "https://api.bls.gov/publicAPI/v2/timeseries/data/"
      json = Sources.http_json(url, method: :post, body: body)
      raise "BLS: #{json["status"]}: #{json["message"]}" unless json["status"] == "REQUEST_SUCCEEDED"
      json.dig("Results", "series", 0, "data") || []
    end

    def run
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
          val = Float(raw) rescue nil
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
        sleep(1.0)  # be polite to BLS rate limits
      end

      # Compute annual fallback from monthly averages where annual missing.
      monthly_by_year = monthly.group_by { |k, _v| k[0, 4] }
      monthly_by_year.each do |year, pairs|
        next if annual.key?(year)
        next unless pairs.size == 12
        avg = pairs.sum { |_k, v| v } / 12.0
        annual[year] = avg.round(3)
      end

      Sources.validate_positive_numeric!(monthly, "BLS monthly")
      Sources.validate_positive_numeric!(annual,  "BLS annual")

      path = File.join(Sources::DATA_ROOT, "cpi", "us.json")
      prior = Sources.read_json_if_exists(path)
      prior_monthly = prior && prior["monthly"] || {}
      prior_annual  = prior && prior["annual"]  || {}

      base_year = (prior && prior["base_year"]) || "1982-1984=100"

      verdict_m, ratio_m, msg_m = Sources.cpi_drift_check(prior_monthly, monthly)
      Sources.log "BLS drift (monthly): #{msg_m}"
      if verdict_m == :rebase
        Sources.log "BLS: rebase detected — renormalizing prior series by ratio #{ratio_m}"
        prior_monthly = Sources.renormalize(prior_monthly, ratio_m)
        prior_annual  = Sources.renormalize(prior_annual,  ratio_m)
        base_year = "rebased #{Sources.today}"
      end

      merged_monthly = prior_monthly.merge(monthly)
      merged_annual  = prior_annual.merge(annual)

      new_points = (monthly.keys - prior_monthly.keys).size + (annual.keys - prior_annual.keys).size
      range = merged_monthly.keys.minmax

      data = {
        "schema_version" => 1,
        "country"        => "US",
        "base_year"      => base_year,
        "source"         => SOURCE_LABEL,
        "updated_at"     => Sources.today,
        "monthly"        => merged_monthly,
        "annual"         => merged_annual
      }
      Sources.write_json(path, data)

      Sources.log "BLS: #{merged_monthly.size} monthly + #{merged_annual.size} annual data points, range #{range.first}..#{range.last}, #{new_points} new since last run."
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::BLS.run
end
