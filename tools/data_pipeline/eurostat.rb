# frozen_string_literal: true

require_relative "namespace"

require_relative "provider"

# Eurozone HICP from Eurostat dataset prc_hicp_midx.
#
# Response is SDMX-JSON: `value` is a flat hash of string-index => number,
# and `dimension.time.category.index` maps period strings ("YYYY-MM") to
# those same indexes. We invert that mapping to recover the monthly series.
module Tools
  module DataPipeline
    class Eurostat < Provider
      URL = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/" \
            "prc_hicp_midx?geo=EA&coicop=CP00&unit=I15&format=JSON"

      configure(
        country_code: "eu",
        country_label: "Eurozone",
        source_label: "Eurostat prc_hicp_midx (HICP, EA all current members, CP00, 2015=100)",
        default_base_year: "2015=100",
        log_label: "Eurostat",
        provider_id: "eurostat"
      )

      def fetch
        body = Tools::DataPipeline.http_json(URL)
        time_index = body.dig("dimension", "time", "category", "index") || {}
        values     = body["value"] || {}

        monthly = {}
        time_index.each do |period, idx|
          v = values[idx.to_s]
          next if v.nil?
          # Skip annual aggregate-style periods, if any (Eurostat may emit "2024" too).
          next unless period.match?(/\A\d{4}-\d{2}\z/)

          monthly[period] = Float(v)
        end

        annual = {}
        monthly.group_by { |k, _| k[0, 4] }.each do |year, pairs|
          next unless pairs.size == 12

          annual[year] = (pairs.sum { |_, v| v } / 12.0).round(3)
        end

        [monthly, annual]
      end
    end
  end
end

Tools::DataPipeline::Eurostat.run if __FILE__ == $PROGRAM_NAME
