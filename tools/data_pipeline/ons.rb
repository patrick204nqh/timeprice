# frozen_string_literal: true

require_relative "namespace"

require_relative "provider"

# UK CPI series D7BT (CPI all-items index, 2015=100) from ONS.
# Note: the developer.ons.gov.uk v0 API was retired 2024-11-25. The public
# www.ons.gov.uk timeseries data endpoint still works and returns the same
# {years:[], months:[], quarters:[]} structure.
module Tools
  module DataPipeline
    class ONS < Provider
      URL = "https://www.ons.gov.uk/economy/inflationandpriceindices/timeseries/d7bt/mm23/data"

      MONTH_ABBR = %w[jan feb mar apr may jun jul aug sep oct nov dec].each_with_index.to_h do |m, i|
        [m, format("%02d", i + 1)]
      end

      configure(
        country_code: "uk",
        country_label: "United Kingdom",
        source_label: "ONS D7BT — UK CPI all-items index (2015=100)",
        default_base_year: "2015=100",
        log_label: "ONS",
        provider_id: "ons"
      )

      def parse_month(entry)
        # entry["date"] looks like "2024 OCT" or sometimes "2024 OCTOBER"; entry["month"] is the month name.
        year  = entry["year"]
        mname = (entry["month"] || "").to_s.strip.downcase[0, 3]
        m = MONTH_ABBR[mname]
        return nil unless year && m

        "#{year}-#{m}"
      end

      def fetch
        body = Tools::DataPipeline.http_json(URL, headers: { "User-Agent" => Tools::DataPipeline::USER_AGENT })

        monthly = {}
        (body["months"] || []).each do |row|
          period = parse_month(row)
          next unless period

          monthly[period] = Float(row["value"])
        end
        annual = {}
        (body["years"] || []).each do |row|
          y = row["year"] || row["date"]
          annual[y.to_s] = Float(row["value"])
        end

        [monthly, annual]
      end
    end
  end
end

Tools::DataPipeline::ONS.run if __FILE__ == $PROGRAM_NAME
