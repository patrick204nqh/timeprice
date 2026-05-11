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
require_relative "fx_year_file"

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
    # VND per USD, annual averages. Routes each year to one of two homes:
    #   - years with a daily-coverage file (1999+) → annual block on that file
    #   - years without (pre-1999)                → data/fx/_annual.json
    SOURCE_LABEL_VND = "World Bank PA.NUS.FCRF"

    def run_vnd_fx
      annual = fetch_indicator("VNM", "PA.NUS.FCRF")
      Sources.validate_positive_numeric!(annual, "WorldBank VND/USD annual")

      per_year_touched = 0
      sparse_payload = {}

      annual.each do |year, rate|
        rate_r = rate.round(2)
        if daily_year_exists?(year)
          Sources::FxYearFile.new(year).write_annual(
            annual_by_currency: { "VND" => rate_r },
            provider_id: "world_bank",
            source_label: SOURCE_LABEL_VND
          )
          per_year_touched += 1
        else
          sparse_payload[year.to_s] = { "VND" => rate_r }
        end
      end

      if sparse_payload.any?
        Sources::FxAnnualFile.write(
          annual_by_year_currency: sparse_payload,
          provider_id: "world_bank",
          source_label: SOURCE_LABEL_VND
        )
      end

      Sources.log "WorldBank(VND FX): #{annual.size} annual data points " \
                  "(#{per_year_touched} into per-year files, #{sparse_payload.size} into _annual.json), " \
                  "range #{annual.keys.minmax.join("..")}."
    end

    def daily_year_exists?(year)
      File.exist?(File.join(Sources::DATA_ROOT, "fx", "usd", "#{year}.json"))
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::WorldBank.run_vn_cpi
  Sources::WorldBank.run_vnd_fx
end
