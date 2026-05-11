# frozen_string_literal: true

require_relative "provider"

# Vietnam CPI from the IMF Data Portal (api.imf.org), SDMX 2.1.
#
# Public endpoint, no API key. Provides monthly CPI all-items index from the
# CPI dataflow with ~2-3 month lag — much fresher than World Bank's annual
# FP.CPI.TOTL. CountryFile + MergePolicy layer this monthly series on top
# of the annual baseline that WorldBank's Vietnam provider writes first,
# so vn.json carries both granularities with per-period provenance.
#
# Historical note: the original IMF SDMX service at dataservices.imf.org
# (SDMX_JSON.svc/IFS) was decommissioned in 2025 when the new IMF Data
# Portal launched. The CPI dataflow on the new portal replaces what was
# previously the M.<COUNTRY>.PCPI_IX key on the IFS dataflow.
module Sources
  class IMF < Provider
    BASE_URL = "https://api.imf.org/external/sdmx/2.1"
    # CPI dataflow key: COUNTRY.INDEX_TYPE.COICOP_1999.TYPE_OF_TRANSFORMATION.FREQUENCY
    #   VNM      = Vietnam
    #   CPI      = consumer price index
    #   _T       = total (all items)
    #   IX       = index level (not change rates)
    #   M        = monthly
    VN_KEY     = "VNM.CPI._T.IX.M"
    START      = "1990-01"

    configure(
      country_code: "vn",
      country_label: "Vietnam",
      source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
      default_base_year: "2010=100",
      log_label: "IMF",
      provider_id: "imf"
    )

    def fetch
      body = fetch_sdmx_json
      time_periods = extract_time_periods(body)
      monthly = parse_monthly(body, time_periods)
      annual  = derive_annual(monthly)
      [monthly, annual]
    end

    private

    def fetch_sdmx_json
      url = "#{BASE_URL}/data/CPI/#{VN_KEY}?startPeriod=#{START}"
      # SDMX-ML XML is the default; the new portal returns SDMX-JSON only
      # when the Accept header is application/json (NOT the formal SDMX
      # JSON media type, which 500s on this endpoint).
      Sources.http_json(url, headers: { "Accept" => "application/json" })
    end

    # Time periods come from structure.dimensions.observation[0].values, in
    # order. Each observation in a series is keyed by its index into this
    # list (as a string). Format from IMF is "YYYY-MMM" (e.g. "2026-M03");
    # we normalize to "YYYY-MM" to match every other monthly source.
    def extract_time_periods(body)
      values = body.dig("structure", "dimensions", "observation", 0, "values") || []
      values.map { |v| normalize_period(v["id"]) }
    end

    def normalize_period(period)
      m = period.match(/\A(\d{4})-M(\d{2})\z/)
      m ? "#{m[1]}-#{m[2]}" : nil
    end

    def parse_monthly(body, time_periods)
      series = body.dig("dataSets", 0, "series") || {}
      series.values.each_with_object({}) do |ser, h|
        (ser["observations"] || {}).each do |idx_str, obs|
          period = time_periods[idx_str.to_i]
          value  = obs && obs[0]
          next if period.nil? || value.nil?

          h[period] = Float(value)
        end
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
