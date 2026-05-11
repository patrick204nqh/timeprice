# frozen_string_literal: true

require_relative "_common"

# World Bank fetchers.
#
#   * Vietnam CPI (annual only) via FP.CPI.TOTL  -> data/cpi/vn.json
#   * Vietnam VND/USD official annual avg via PA.NUS.FCRF — written as a
#     single anchor rate per year into data/fx/usd/<year>.json under "01-02".
#     Frankfurter doesn't carry VND; this fills the gap at annual resolution.
#
# Also exposes a fetch_cpi(country_iso3) helper so the e-Stat fallback for
# Japan can reuse it.
module Sources
  module WorldBank
    SOURCE_CPI       = "World Bank FP.CPI.TOTL (annual)"
    SOURCE_VND_FX    = "World Bank PA.NUS.FCRF — VND/USD official annual avg (Frankfurter has no VND)"

    module_function

    def fetch_indicator(country_iso3, indicator)
      url = "https://api.worldbank.org/v2/country/#{country_iso3}/indicator/#{indicator}?format=json&per_page=200"
      body = Sources.http_json(url)
      raise "World Bank: unexpected shape for #{country_iso3}/#{indicator}" unless body.is_a?(Array) && body.size >= 2
      (body[1] || []).each_with_object({}) do |row, h|
        val = row["value"]
        next if val.nil?
        h[row["date"]] = Float(val)
      end
    end

    def write_cpi(country_code, iso3, label_country)
      annual = fetch_indicator(iso3, "FP.CPI.TOTL")
      Sources.validate_positive_numeric!(annual, "WorldBank #{country_code} annual")
      path = File.join(Sources::DATA_ROOT, "cpi", "#{country_code}.json")
      prior = Sources.read_json_if_exists(path)
      prior_annual = prior && prior["annual"] || {}

      verdict, ratio, msg = Sources.cpi_drift_check(prior_annual, annual)
      Sources.log "WorldBank #{country_code} drift: #{msg}"
      base_year = (prior && prior["base_year"]) || "2010=100"
      if verdict == :rebase
        Sources.log "WorldBank #{country_code}: rebase — renormalizing prior by ratio #{ratio}"
        prior_annual = Sources.renormalize(prior_annual, ratio)
        base_year = "rebased #{Sources.today}"
      end

      merged_annual = prior_annual.merge(annual)
      new_points = (annual.keys - prior_annual.keys).size
      range = merged_annual.keys.minmax

      data = {
        "schema_version" => 1,
        "country"        => country_code.upcase,
        "base_year"      => base_year,
        "source"         => SOURCE_CPI,
        "updated_at"     => Sources.today,
        "monthly"        => (prior && prior["monthly"]) || {},
        "annual"         => merged_annual
      }
      Sources.write_json(path, data)
      Sources.log "WorldBank(#{label_country}): 0 monthly + #{merged_annual.size} annual data points, range #{range.first}..#{range.last}, #{new_points} new since last run."
    end

    def run_vn_cpi
      write_cpi("vn", "VNM", "Vietnam")
    end

    def run_jp_cpi_fallback
      write_cpi("jp", "JPN", "Japan")
    end

    # Write VND/USD annual averages into the per-year FX files as a single
    # anchor at YYYY-01-02. The library's nearest-date fallback (±7 days) will
    # NOT bridge a full year — by design, callers asking for VND on arbitrary
    # mid-year dates must accept annual granularity. The README + source label
    # document this.
    def run_vnd_fx
      annual = fetch_indicator("VNM", "PA.NUS.FCRF")  # VND per USD
      Sources.validate_positive_numeric!(annual, "WorldBank VND/USD annual")
      touched = 0
      annual.each do |year, rate|
        path = File.join(Sources::DATA_ROOT, "fx", "usd", "#{year}.json")
        prior = Sources.read_json_if_exists(path) || {
          "schema_version" => 1, "base" => "USD", "year" => year.to_i,
          "source" => "Frankfurter (ECB) + World Bank VND annual",
          "rates" => {}
        }
        rates = prior["rates"] || {}
        anchor = "#{year}-01-02"
        rates[anchor] ||= {}
        rates[anchor]["VND"] = rate.round(2)
        # Mark VND anchor on every existing date in that year for the entire
        # year, so daily lookups for any date return the annual VND figure.
        # This is intentional: VND data is annual; we replicate it across days.
        rates.each_key do |date_str|
          rates[date_str]["VND"] ||= rate.round(2)
        end
        prior["rates"]      = rates
        prior["updated_at"] = Sources.today
        prior["source"]     = "Frankfurter (ECB) for EUR/GBP/JPY; World Bank PA.NUS.FCRF for VND (annual avg, broadcast to every day in year)"
        Sources.write_json(path, prior)
        touched += 1
      end
      Sources.log "WorldBank(VND FX): #{annual.size} annual data points written across #{touched} year files, range #{annual.keys.minmax.join('..')}."
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::WorldBank.run_vn_cpi
  Sources::WorldBank.run_vnd_fx
end
