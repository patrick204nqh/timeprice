# frozen_string_literal: true

require_relative "_common"
require_relative "provider"

# World Bank fetchers.
#
#   * Vietnam CPI (annual only) via FP.CPI.TOTL  -> data/cpi/vn.json
#   * Vietnam VND/USD official annual avg via PA.NUS.FCRF — written as an
#     `annual` block on data/fx/usd/<year>.json. Frankfurter doesn't carry
#     VND; this fills the gap honestly at annual resolution. The Exchange
#     lookup falls back from daily to annual and tags the result accordingly.
#
# Also exposes a fetch_cpi(country_iso3) helper so the e-Stat fallback for
# Japan can reuse it.
module Sources
  module WorldBank
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

    def run_vn_cpi
      VietnamCPI.run
    end

    def run_jp_cpi_fallback
      JapanCPI.run
    end

    # Provider subclasses for the two CPI countries served by World Bank.
    # Both share `provider_id: "world_bank"`; the country_code disambiguates
    # which file each writes to. The VN source_label intentionally names
    # only WB — IMF runs second and re-labels the file to reflect the chain.
    class VietnamCPI < Provider
      configure(
        country_code: "vn",
        country_label: "Vietnam",
        source_label: "World Bank FP.CPI.TOTL (annual)",
        default_base_year: "2010=100",
        log_label: "WorldBank",
        provider_id: "world_bank"
      )

      def fetch
        [{}, WorldBank.fetch_indicator("VNM", "FP.CPI.TOTL")]
      end
    end

    class JapanCPI < Provider
      configure(
        country_code: "jp",
        country_label: "Japan",
        source_label: "World Bank FP.CPI.TOTL (annual, JP fallback)",
        default_base_year: "2010=100",
        log_label: "WorldBank",
        provider_id: "world_bank"
      )

      def fetch
        [{}, WorldBank.fetch_indicator("JPN", "FP.CPI.TOTL")]
      end
    end

    # Write VND/USD annual averages into the per-year FX files under a
    # top-level `annual` block (one entry per currency). Daily rates are
    # left untouched — Frankfurter populates EUR/GBP/JPY there. The library's
    # Exchange lookup falls back from daily to annual when daily is missing
    # and tags the resolved rate with Granularity::ANNUAL so the caller knows
    # the precision they actually got.
    def run_vnd_fx
      annual = fetch_indicator("VNM", "PA.NUS.FCRF") # VND per USD
      Sources.validate_positive_numeric!(annual, "WorldBank VND/USD annual")
      touched = 0
      annual.each do |year, rate|
        path = File.join(Sources::DATA_ROOT, "fx", "usd", "#{year}.json")
        prior = Sources.read_json_if_exists(path) || {
          "schema_version" => 2, "base" => "USD", "year" => year.to_i,
          "source" => "Frankfurter (ECB) + World Bank VND annual",
          "rates" => {}
        }
        annual_block = prior["annual"] || {}
        annual_block["VND"] = rate.round(2)
        prior["annual"]     = annual_block
        prior["updated_at"] = Sources.today
        prior["source"]     =
          "Frankfurter (ECB) for EUR/GBP/JPY (daily); World Bank PA.NUS.FCRF for VND (annual)"
        Sources.write_json(path, prior)
        touched += 1
      end
      Sources.log "WorldBank(VND FX): #{annual.size} annual data points written across #{touched} year files, range #{annual.keys.minmax.join("..")}."
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::WorldBank.run_vn_cpi
  Sources::WorldBank.run_vnd_fx
end
