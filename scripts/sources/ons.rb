# frozen_string_literal: true

require_relative "_common"

# UK CPI series D7BT (CPI all-items index, 2015=100) from ONS.
# Note: the developer.ons.gov.uk v0 API was retired 2024-11-25. The public
# www.ons.gov.uk timeseries data endpoint still works and returns the same
# {years:[], months:[], quarters:[]} structure.
module Sources
  module ONS
    SOURCE_LABEL = "ONS D7BT — UK CPI all-items index (2015=100)"
    URL          = "https://www.ons.gov.uk/economy/inflationandpriceindices/timeseries/d7bt/mm23/data"

    module_function

    MONTH_ABBR = %w[jan feb mar apr may jun jul aug sep oct nov dec].each_with_index.to_h { |m, i| [m, format("%02d", i + 1)] }

    def parse_month(entry)
      # entry["date"] looks like "2024 OCT" or sometimes "2024 OCTOBER"; entry["month"] is the month name.
      year  = entry["year"]
      mname = (entry["month"] || "").to_s.strip.downcase[0, 3]
      m = MONTH_ABBR[mname]
      return nil unless year && m
      "#{year}-#{m}"
    end

    def run
      body = Sources.http_json(URL, headers: { "User-Agent" => Sources::USER_AGENT })

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

      Sources.validate_positive_numeric!(monthly, "ONS monthly")
      Sources.validate_positive_numeric!(annual,  "ONS annual")

      path = File.join(Sources::DATA_ROOT, "cpi", "uk.json")
      prior = Sources.read_json_if_exists(path)
      prior_monthly = prior && prior["monthly"] || {}
      prior_annual  = prior && prior["annual"]  || {}

      verdict, ratio, msg = Sources.cpi_drift_check(prior_monthly, monthly)
      Sources.log "ONS drift (monthly): #{msg}"
      base_year = (prior && prior["base_year"]) || "2015=100"
      if verdict == :rebase
        Sources.log "ONS: rebase — renormalizing prior series by ratio #{ratio}"
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
        "country"        => "UK",
        "base_year"      => base_year,
        "source"         => SOURCE_LABEL,
        "updated_at"     => Sources.today,
        "monthly"        => merged_monthly,
        "annual"         => merged_annual
      }
      Sources.write_json(path, data)
      Sources.log "ONS: #{merged_monthly.size} monthly + #{merged_annual.size} annual data points, range #{range.first}..#{range.last}, #{new_points} new since last run."
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::ONS.run
end
