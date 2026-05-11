# frozen_string_literal: true

require_relative "provider"

# Vietnam CPI from IMF International Financial Statistics (IFS).
#
# Public SDMX_JSON endpoint, no API key. Provides monthly CPI all-items
# index (PCPI_IX) with ~2-3 month lag — much fresher than World Bank's
# annual-only FP.CPI.TOTL. CountryFile + MergePolicy layer this monthly
# series on top of the annual baseline that WorldBank's Vietnam provider
# writes first, so vn.json carries both granularities with per-period
# provenance recording which source supplied each point.
module Sources
  class IMF < Provider
    BASE_URL = "https://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/IFS"
    VN_URL   = "#{BASE_URL}/M.VN.PCPI_IX".freeze

    configure(
      country_code: "vn",
      country_label: "Vietnam",
      source_label: "IMF IFS PCPI_IX (monthly) + World Bank FP.CPI.TOTL (annual)",
      default_base_year: "2010=100",
      log_label: "IMF",
      provider_id: "imf"
    )

    def fetch
      observations = fetch_observations(VN_URL)
      monthly = parse_monthly(observations)
      annual  = derive_annual(monthly)
      [monthly, annual]
    end

    private

    def fetch_observations(url)
      body = Sources.http_json(url)
      series = body.dig("CompactData", "DataSet", "Series")
      raise "IMF: empty series for #{url}" if series.nil?

      obs = series["Obs"]
      obs.is_a?(Array) ? obs : [obs].compact
    end

    def parse_monthly(observations)
      observations.each_with_object({}) do |row, h|
        period = row["@TIME_PERIOD"]
        value  = row["@OBS_VALUE"]
        next if period.nil? || value.nil?
        next unless period.match?(/\A\d{4}-\d{2}\z/)

        h[period] = Float(value)
      end
    end

    def derive_annual(monthly)
      monthly.group_by { |k, _| k[0, 4] }.each_with_object({}) do |(year, pairs), h|
        next unless pairs.size == 12

        h[year] = (pairs.sum { |_, v| v } / 12.0).round(3)
      end
    end
  end
end

Sources::IMF.run if __FILE__ == $PROGRAM_NAME
