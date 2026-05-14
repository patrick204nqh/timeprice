# frozen_string_literal: true

require_relative "namespace"

require_relative "provider"

# Australian CPI from the ABS Data API (data.api.abs.gov.au), SDMX-JSON.
#
# Public endpoint, no API key. Series CPI release 6401.0 is published
# quarterly only — there is no monthly equivalent. We emit only a quarterly
# series ("YYYY-Qn" keys); the annual baseline comes from World Bank
# (`WorldBank.run_au_cpi_fallback`). CpiLookup synthesizes an
# annual-from-quarterly-avg at read time when callers ask for "YYYY".
#
# Why we don't derive annual here: ABS's official headline annual CPI is a
# specific reference period (financial year / June quarter, series-dependent)
# rather than an arithmetic mean of four quarterly index numbers. A
# locally-averaged value would silently disagree (~0.5–1% drift on a rising
# index) with anything an Australian user cross-checks against the ABS site,
# and MergePolicy.layer ordering would clobber the WB baseline depending on
# run sequence.
#
# Dataflow key: MEASURE.INDEX.TSEST.REGION.FREQ
#   1      = Index Numbers (was 3 before ABS reorganized CL_CPI_MEASURES in
#            CPI v2.0.0; code 3 now means "Percentage change from previous year")
#   10001  = All groups CPI
#   10     = Original (not seasonally adjusted) — matches the headline number
#   50     = Australia (formerly "weighted average of eight capital cities" —
#            same series, renamed in CL_CPI_REGION)
#   Q      = Quarterly
#
# NOTE: ABS's SDMX endpoint occasionally serves XML even when JSON is
# requested. If a future run starts returning text/xml, switch to the
# https://api.abs.gov.au/data/... mirror or pin Accept to the formal SDMX
# JSON media type ("application/vnd.sdmx.data+json;version=1.0.0").
module Tools
  module DataPipeline
    class ABS < Provider
      BASE_URL  = "https://data.api.abs.gov.au/rest"
      DATAFLOW  = "CPI"
      KEY       = "1.10001.10.50.Q"
      START     = "1948-Q3"

      configure(
        country_code: "au",
        country_label: "Australia",
        source_label: "ABS 6401.0 Consumer Price Index (quarterly) + World Bank (annual baseline)",
        default_base_year: "2011-2012=100",
        log_label: "ABS",
        provider_id: "abs"
      )

      def fetch
        body = fetch_sdmx_json
        time_periods = extract_time_periods(body)
        quarterly = parse_quarterly(body, time_periods)
        [{}, quarterly, {}]
      end

      private

      def fetch_sdmx_json
        url = "#{BASE_URL}/data/#{DATAFLOW}/#{KEY}?startPeriod=#{START}&format=jsondata"
        Tools::DataPipeline.http_json(url, headers: {
                                        "Accept" => "application/vnd.sdmx.data+json;version=1.0.0",
                                      })
      end

      # ABS migrated to SDMX-JSON 2.0.0, which wraps the payload in a top-level
      # "data" object. Tolerate the legacy 1.0.0 shape too so we don't break if
      # the mirror at api.abs.gov.au keeps serving the old format.
      def envelope(body)
        body["data"] || body
      end

      def extract_time_periods(body)
        env = envelope(body)
        values = env.dig("structures", 0, "dimensions", "observation", 0, "values") ||
                 env.dig("structure", "dimensions", "observation", 0, "values") ||
                 []
        values.map { |v| normalize_period(v["id"]) }
      end

      # ABS quarter periods arrive as "2024-Q3". Already canonical.
      def normalize_period(period)
        period if period.is_a?(String) && period.match?(/\A\d{4}-Q[1-4]\z/)
      end

      def parse_quarterly(body, time_periods)
        env = envelope(body)
        series = env.dig("dataSets", 0, "series") || {}
        series.values.each_with_object({}) do |ser, h|
          (ser["observations"] || {}).each do |idx_str, obs|
            period = time_periods[idx_str.to_i]
            value  = obs && obs[0]
            next if period.nil? || value.nil?

            h[period] = Float(value)
          end
        end
      end
    end
  end
end

Tools::DataPipeline::ABS.run if __FILE__ == $PROGRAM_NAME
