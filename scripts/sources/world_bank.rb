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

    def run_au_cpi_fallback = AustraliaCPI.run
    def run_ca_cpi_fallback = CanadaCPI.run
    def run_kr_cpi_fallback = KoreaCPI.run
    def run_cn_cpi          = ChinaCPI.run
    def run_ru_cpi          = RussiaCPI.run

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

    # Australia annual CPI baseline. ABS quarterly (scripts/sources/abs.rb)
    # layers on top via CountryFile + MergePolicy.
    class AustraliaCPI < Provider
      configure(
        country_code: "au",
        country_label: "Australia",
        source_label: "World Bank FP.CPI.TOTL (annual, AU baseline)",
        default_base_year: "2010=100",
        log_label: "WorldBank",
        provider_id: "world_bank"
      )

      def fetch
        [{}, WorldBank.fetch_indicator("AUS", "FP.CPI.TOTL")]
      end
    end

    # Canada annual CPI baseline. StatCan monthly layers on top.
    class CanadaCPI < Provider
      configure(
        country_code: "ca",
        country_label: "Canada",
        source_label: "World Bank FP.CPI.TOTL (annual, CA baseline)",
        default_base_year: "2010=100",
        log_label: "WorldBank",
        provider_id: "world_bank"
      )

      def fetch
        [{}, WorldBank.fetch_indicator("CAN", "FP.CPI.TOTL")]
      end
    end

    # Korea annual CPI baseline. KOSIS monthly layers on top.
    class KoreaCPI < Provider
      configure(
        country_code: "kr",
        country_label: "Korea, Rep.",
        source_label: "World Bank FP.CPI.TOTL (annual, KR baseline)",
        default_base_year: "2010=100",
        log_label: "WorldBank",
        provider_id: "world_bank"
      )

      def fetch
        [{}, WorldBank.fetch_indicator("KOR", "FP.CPI.TOTL")]
      end
    end

    # China — primary source for v1 (NBS scraper deferred). Annual only.
    class ChinaCPI < Provider
      configure(
        country_code: "cn",
        country_label: "China",
        source_label: "World Bank FP.CPI.TOTL (annual)",
        default_base_year: "2010=100",
        log_label: "WorldBank",
        provider_id: "world_bank"
      )

      def fetch
        [{}, WorldBank.fetch_indicator("CHN", "FP.CPI.TOTL")]
      end
    end

    # Russia — primary source for v1. Annual only.
    class RussiaCPI < Provider
      configure(
        country_code: "ru",
        country_label: "Russia",
        source_label: "World Bank FP.CPI.TOTL (annual)",
        default_base_year: "2010=100",
        log_label: "WorldBank",
        provider_id: "world_bank"
      )

      def fetch
        [{}, WorldBank.fetch_indicator("RUS", "FP.CPI.TOTL")]
      end
    end

    # VND per USD, annual averages. All years land in the single
    # data/fx/usd/_annual.json — the canonical home for annual FX rates.
    SOURCE_LABEL_VND = "World Bank PA.NUS.FCRF"

    def run_vnd_fx
      annual = fetch_indicator("VNM", "PA.NUS.FCRF")
      Sources.validate_positive_numeric!(annual, "WorldBank VND/USD annual")

      payload = annual.to_h { |year, rate| [year.to_s, { "VND" => rate.round(2) }] }
      Sources::FxAnnualFile.write(
        annual_by_year_currency: payload,
        provider_id: "world_bank",
        source_label: SOURCE_LABEL_VND
      )

      Sources.log "WorldBank(VND FX): #{annual.size} annual data points into _annual.json, " \
                  "range #{annual.keys.minmax.join("..")}."
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::WorldBank.run_vn_cpi
  Sources::WorldBank.run_vnd_fx
  Sources::WorldBank.run_au_cpi_fallback
  Sources::WorldBank.run_ca_cpi_fallback
  Sources::WorldBank.run_kr_cpi_fallback
  Sources::WorldBank.run_cn_cpi
  Sources::WorldBank.run_ru_cpi
end
