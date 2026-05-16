# frozen_string_literal: true

require_relative "namespace"

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
# Also exposes a fetch_cpi(country_iso3) helper for shared reuse.
require_relative "fx_year_file"

module Tools
  module DataPipeline
    module WorldBank
      module_function

      def fetch_indicator(country_iso3, indicator)
        url = "https://api.worldbank.org/v2/country/#{country_iso3}/indicator/#{indicator}?format=json&per_page=200"
        body = Tools::DataPipeline.http_json(url)
        unless body.is_a?(Array) && body.size >= 2
          fail ShapeError, "World Bank: unexpected shape for #{country_iso3}/#{indicator}"
        end

        (body[1] || []).each_with_object({}) do |row, h|
          val = row["value"]
          next if val.nil?

          h[row["date"]] = Float(val)
        end
      end

      def run_vn_cpi
        VietnamCPI.run
      end

      def run_au_cpi_fallback = AustraliaCPI.run
      def run_ca_cpi_fallback = CanadaCPI.run
      def run_kr_cpi_fallback = KoreaCPI.run
      def run_cn_cpi          = ChinaCPI.run
      def run_ru_cpi          = RussiaCPI.run

      # Builds and registers a one-shot WorldBank CPI Provider subclass.
      # Used for every WB-CPI country: all share the same fetch shape
      # (annual-only FP.CPI.TOTL) so the only per-country variation is
      # (code, iso3, label, source_label suffix).
      def self.register_cpi(code:, iso3:, label:, suffix: nil, register: true)
        full_label = "#{["World Bank FP.CPI.TOTL (annual", suffix].compact.join(", ")})"
        klass = Class.new(Provider) do
          define_singleton_method(:iso3) { iso3 }
          define_method(:fetch) do
            Series.build(annual: WorldBank.fetch_indicator(self.class.iso3, "FP.CPI.TOTL"))
          end
        end
        klass.configure(
          country_code: code,
          country_label: label,
          source_label: full_label,
          default_base_year: "2010=100",
          log_label: "WorldBank",
          provider_id: "world_bank",
          priority: 30,
          register: register
        )
        klass
      end

      # Declaration order is the registry order — preserve the original
      # run sequence (VN, AU, CA, KR, CN, RU) for byte-identical output.
      VietnamCPI = register_cpi(code: "vn", iso3: "VNM", label: "Vietnam")
      AustraliaCPI = register_cpi(code: "au", iso3: "AUS", label: "Australia", suffix: "AU baseline")
      CanadaCPI   = register_cpi(code: "ca", iso3: "CAN", label: "Canada",     suffix: "CA baseline")
      KoreaCPI    = register_cpi(code: "kr", iso3: "KOR", label: "Korea, Rep.", suffix: "KR baseline")
      ChinaCPI    = register_cpi(code: "cn", iso3: "CHN", label: "China")
      RussiaCPI   = register_cpi(code: "ru", iso3: "RUS", label: "Russia")
      JapanCPI = register_cpi(code: "jp", iso3: "JPN", label: "Japan")

      # VND per USD, annual averages. All years land in the single
      # data/fx/usd/_annual.json — the canonical home for annual FX rates.
      SOURCE_LABEL_VND = "World Bank PA.NUS.FCRF"

      def run_vnd_fx
        annual = fetch_indicator("VNM", "PA.NUS.FCRF")
        Tools::DataPipeline.validate_positive_numeric!(annual, "WorldBank VND/USD annual")

        payload = annual.to_h { |year, rate| [year.to_s, { "VND" => rate.round(2) }] }
        Tools::DataPipeline::FxAnnualFile.write(
          annual_by_year_currency: payload,
          provider_id: "world_bank",
          source_label: SOURCE_LABEL_VND
        )

        Tools::DataPipeline.log "WorldBank(VND FX): #{annual.size} annual data points into _annual.json, " \
                                "range #{annual.keys.minmax.join("..")}."
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Tools::DataPipeline::WorldBank.run_vn_cpi
  Tools::DataPipeline::WorldBank.run_vnd_fx
  Tools::DataPipeline::WorldBank.run_au_cpi_fallback
  Tools::DataPipeline::WorldBank.run_ca_cpi_fallback
  Tools::DataPipeline::WorldBank.run_kr_cpi_fallback
  Tools::DataPipeline::WorldBank.run_cn_cpi
  Tools::DataPipeline::WorldBank.run_ru_cpi
end
