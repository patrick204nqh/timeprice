# frozen_string_literal: true

require_relative "_common"

# Eurozone HICP from Eurostat dataset prc_hicp_midx.
#
# Response is SDMX-JSON: `value` is a flat hash of string-index => number,
# and `dimension.time.category.index` maps period strings ("YYYY-MM") to
# those same indexes. We invert that mapping to recover the monthly series.
module Sources
  module Eurostat
    SOURCE_LABEL = "Eurostat prc_hicp_midx (HICP, EA all current members, CP00, 2015=100)"
    URL          = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/prc_hicp_midx?geo=EA&coicop=CP00&unit=I15&format=JSON"

    module_function

    def run
      body = Sources.http_json(URL)
      time_index = body.dig("dimension", "time", "category", "index") || {}
      values     = body["value"] || {}

      # `time_index` is { "1996-01" => 0, "1996-02" => 1, ... }
      # `values` is    { "0" => 70.97, ... }  (some indexes may be missing)
      monthly = {}
      time_index.each do |period, idx|
        v = values[idx.to_s]
        next if v.nil?
        # Skip annual aggregate-style periods, if any (Eurostat may emit "2024" too).
        next unless period.match?(/\A\d{4}-\d{2}\z/)
        monthly[period] = Float(v)
      end

      # Synthesize annuals as 12-month averages where complete years available.
      annual = {}
      monthly.group_by { |k, _| k[0, 4] }.each do |year, pairs|
        next unless pairs.size == 12
        annual[year] = (pairs.sum { |_, v| v } / 12.0).round(3)
      end

      Sources.validate_positive_numeric!(monthly, "Eurostat monthly")
      Sources.validate_positive_numeric!(annual,  "Eurostat annual")

      path = File.join(Sources::DATA_ROOT, "cpi", "eu.json")
      prior = Sources.read_json_if_exists(path)
      prior_monthly = prior && prior["monthly"] || {}
      prior_annual  = prior && prior["annual"]  || {}

      verdict, ratio, msg = Sources.cpi_drift_check(prior_monthly, monthly)
      Sources.log "Eurostat drift (monthly): #{msg}"
      base_year = (prior && prior["base_year"]) || "2015=100"
      if verdict == :rebase
        Sources.log "Eurostat: rebase — renormalizing prior by ratio #{ratio}"
        prior_monthly = Sources.renormalize(prior_monthly, ratio)
        prior_annual  = Sources.renormalize(prior_annual,  ratio)
        base_year = "rebased #{Sources.today}"
      end

      merged_monthly = prior_monthly.merge(monthly)
      merged_annual  = prior_annual.merge(annual)
      new_points = (monthly.keys - prior_monthly.keys).size + (annual.keys - prior_annual.keys).size
      range = merged_monthly.keys.minmax

      data = {
        "schema_version" => 1,
        "country"        => "EU",
        "base_year"      => base_year,
        "source"         => SOURCE_LABEL,
        "updated_at"     => Sources.today,
        "monthly"        => merged_monthly,
        "annual"         => merged_annual
      }
      Sources.write_json(path, data)
      Sources.log "Eurostat: #{merged_monthly.size} monthly + #{merged_annual.size} annual data points, range #{range.first}..#{range.last}, #{new_points} new since last run."
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::Eurostat.run
end
