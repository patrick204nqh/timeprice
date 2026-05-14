# frozen_string_literal: true

require_relative "namespace"

require_relative "provider"

# Canadian CPI from Statistics Canada's Web Data Service.
#
# Public, no API key. Pulls the all-items CPI for Canada (table 18-10-0004-01,
# "Consumer Price Index, monthly, not seasonally adjusted") via the
# `getDataFromVectorsAndLatestNPeriods` endpoint. Vector v41690973 is the
# all-items Canada series; the WDS API exposes one observation per refPer.
#
# Annual values are derived as the mean of the 12 monthly observations in a
# complete year so the gem can serve "YYYY" lookups without rounding to one
# arbitrary month.
module Tools
  module DataPipeline
    class StatCan < Provider
      ENDPOINT  = "https://www150.statcan.gc.ca/t1/wds/rest/getDataFromVectorsAndLatestNPeriods"
      VECTOR_ID = 41_690_973
      # 3000 months covers >250 years; the table only goes back to 1914, so
      # this is generous enough to always grab the full series in one call.
      LATEST_N  = 3000

      configure(
        country_code: "ca",
        country_label: "Canada",
        source_label: "Statistics Canada WDS (table 18-10-0004-01, monthly) + World Bank (annual baseline)",
        default_base_year: "2002=100",
        log_label: "StatCan",
        provider_id: "statcan"
      )

      def fetch
        body = fetch_payload
        points = extract_points(body)
        monthly = parse_monthly(points)
        annual  = derive_annual(monthly)
        Series.build(monthly: monthly, annual: annual)
      end

      private

      def fetch_payload
        raw = Tools::DataPipeline.http_request(
          ENDPOINT,
          method: :post,
          body: [{ "vectorId" => VECTOR_ID, "latestN" => LATEST_N }]
        )
        JSON.parse(raw)
      end

      def extract_points(body)
        # WDS returns [{ "status" => "SUCCESS", "object" => { "vectorDataPoint" => [...] } }]
        entry = Array(body).first
        raise "StatCan: unexpected payload shape: #{body.class}" unless entry.is_a?(Hash)
        raise "StatCan: status #{entry["status"].inspect}" if entry["status"] && entry["status"] != "SUCCESS"

        entry.dig("object", "vectorDataPoint") || []
      end

      def parse_monthly(points)
        points.each_with_object({}) do |p, h|
          ref = p["refPer"] # e.g. "2024-03-01"
          val = p["value"]
          next if ref.nil? || val.nil?

          h[ref[0, 7]] = Float(val)
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
end

Tools::DataPipeline::StatCan.run if __FILE__ == $PROGRAM_NAME
