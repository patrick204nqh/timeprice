# frozen_string_literal: true

require_relative "namespace"

require_relative "provider"
require_relative "fx_year_file"

# IMF Data Portal (api.imf.org), SDMX 2.1.
#
# Public endpoint, no API key. Provides three things this gem leans on:
#
#   * Monthly CPI all-items (CPI dataflow, key COUNTRY.CPI._T.IX.M).
#     One CountryCPI subclass per country layered on top of the World Bank
#     annual baseline. See the CountryCPI subclasses below for the current
#     set — adding a new country means a new subclass here plus a matching
#     register_cpi line in world_bank.rb.
#
#   * RUB/USD exchange rate (ER dataflow, key RUS.XDC_USD.PA_RT.M —
#     domestic currency per USD, period average, monthly).
#     Frankfurter dropped RUB after the ECB suspended reference rates in
#     March 2022; we use IMF period-average rates throughout for
#     consistency, written to _annual.json (annual mean of the 12 monthly
#     observations in each complete year).
#
# Historical note: the original IMF SDMX service at dataservices.imf.org
# (SDMX_JSON.svc/IFS) was decommissioned in 2025 when the new IMF Data
# Portal launched. The CPI dataflow on the new portal replaces what was
# previously the M.<COUNTRY>.PCPI_IX key on the IFS dataflow, and the
# exchange-rate series moved from IFS to the standalone ER dataflow with
# reordered dimensions (COUNTRY.INDICATOR.TYPE_OF_TRANSFORMATION.FREQUENCY).
module Tools
  module DataPipeline
    module IMF
      BASE_URL = "https://api.imf.org/external/sdmx/2.1"

      module_function

      def run_vn_cpi = VietnamCPI.run
      def run_kr_cpi = KoreaCPI.run
      def run_cn_cpi = ChinaCPI.run
      def run_ru_cpi = RussiaCPI.run

      # Pulls the IFS RUB/USD monthly series and writes annual averages into
      # _annual.json. Daily fallback isn't possible from IMF (monthly cadence),
      # so RUB is annual-only — consumers of the Exchange API fall back from
      # daily to annual and tag the result appropriately.
      def run_ru_fx
        monthly = fetch_er_monthly("RUS", "XDC_USD", "PA_RT")
        annual  = derive_annual(monthly)
        Tools::DataPipeline.validate_positive_numeric!(annual, "IMF RUB/USD annual")

        payload = annual.to_h { |year, rate| [year.to_s, { "RUB" => rate.round(4) }] }
        Tools::DataPipeline::FxAnnualFile.write(
          annual_by_year_currency: payload,
          provider_id: "imf",
          source_label: "IMF ER dataflow XDC_USD/PA_RT (period-average, annual mean)"
        )

        Tools::DataPipeline.log "IMF(RUB FX): #{annual.size} annual averages into _annual.json, " \
                                "range #{annual.keys.minmax.join("..")}."
      end

      def fetch_cpi_monthly(country_iso3)
        key  = "#{country_iso3}.CPI._T.IX.M"
        url  = "#{BASE_URL}/data/CPI/#{key}?startPeriod=1990-01"
        body = Tools::DataPipeline.http_json(url, headers: { "Accept" => "application/json" })
        time_periods = extract_time_periods(body)
        parse_observations(body, time_periods)
      end

      # ER (Exchange Rate) dataflow on the new IMF Data Portal.
      # Dimensions: COUNTRY.INDICATOR.TYPE_OF_TRANSFORMATION.FREQUENCY
      #   INDICATOR e.g. "XDC_USD" (domestic currency per USD)
      #   TYPE      e.g. "PA_RT"   (period average)
      def fetch_er_monthly(country_iso3, indicator, type_of_transformation)
        key  = "#{country_iso3}.#{indicator}.#{type_of_transformation}.M"
        url  = "#{BASE_URL}/data/ER/#{key}?startPeriod=1990-01"
        body = Tools::DataPipeline.http_json(url, headers: { "Accept" => "application/json" })
        time_periods = extract_time_periods(body)
        parse_observations(body, time_periods)
      end

      def extract_time_periods(body)
        values = body.dig("structure", "dimensions", "observation", 0, "values") || []
        values.map { |v| normalize_period(v["id"]) }
      end

      def normalize_period(period)
        m = period.match(/\A(\d{4})-M(\d{2})\z/)
        m ? "#{m[1]}-#{m[2]}" : nil
      end

      def parse_observations(body, time_periods)
        series = body.dig("dataSets", 0, "series") || {}
        series.values.each_with_object({}) do |ser, h|
          (ser["observations"] || {}).each do |idx_str, obs|
            period = time_periods[idx_str.to_i]
            value  = obs && obs[0]
            next if period.nil? || value.nil?

            h[period] = Float(value)
          end
        end
      end

      def derive_annual(monthly)
        monthly.group_by { |k, _| k[0, 4] }.each_with_object({}) do |(year, pairs), h|
          next unless pairs.size == 12

          h[year] = (pairs.sum { |_, v| v } / 12.0).round(4)
        end
      end

      # CPI Provider subclasses — all share the same shape, only the country
      # ISO3 used in the SDMX key differs. CountryFile + MergePolicy layer the
      # monthly series on top of whichever annual baseline ran first (today:
      # World Bank for every country).
      class CountryCPI < Tools::DataPipeline::Provider
        def self.iso3 = self::ISO3

        def fetch
          monthly = IMF.fetch_cpi_monthly(self.class.iso3)
          annual  = IMF.derive_annual(monthly)
          Series.build(monthly: monthly, annual: annual)
        end
      end

      CPI_SOURCE_LABEL = "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)"

      # Builds and registers a one-shot IMF CountryCPI subclass. Mirrors
      # WorldBank.register_cpi in shape — per-country variation is only
      # (code, iso3, label). Declaration order is the registry order.
      def self.define_country_cpi(code:, iso3:, label:)
        klass = Class.new(CountryCPI)
        klass.const_set(:ISO3, iso3)
        klass.configure(
          country_code: code,
          country_label: label,
          source_label: CPI_SOURCE_LABEL,
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
        klass
      end

      VietnamCPI     = define_country_cpi(code: "vn", iso3: "VNM", label: "Vietnam")
      KoreaCPI       = define_country_cpi(code: "kr", iso3: "KOR", label: "Korea, Rep.")
      ChinaCPI       = define_country_cpi(code: "cn", iso3: "CHN", label: "China")
      RussiaCPI      = define_country_cpi(code: "ru", iso3: "RUS", label: "Russia")
      BrazilCPI      = define_country_cpi(code: "br", iso3: "BRA", label: "Brazil")
      IndiaCPI       = define_country_cpi(code: "in", iso3: "IND", label: "India")
      MexicoCPI      = define_country_cpi(code: "mx", iso3: "MEX", label: "Mexico")
      SwitzerlandCPI = define_country_cpi(code: "ch", iso3: "CHE", label: "Switzerland")
      SingaporeCPI   = define_country_cpi(code: "sg", iso3: "SGP", label: "Singapore")
      HongKongCPI    = define_country_cpi(code: "hk", iso3: "HKG", label: "Hong Kong SAR, China")
      NewZealandCPI  = define_country_cpi(code: "nz", iso3: "NZL", label: "New Zealand")
      IndonesiaCPI   = define_country_cpi(code: "id", iso3: "IDN", label: "Indonesia")
      TurkeyCPI      = define_country_cpi(code: "tr", iso3: "TUR", label: "Türkiye")
      SouthAfricaCPI = define_country_cpi(code: "za", iso3: "ZAF", label: "South Africa")
      PolandCPI      = define_country_cpi(code: "pl", iso3: "POL", label: "Poland")
      ThailandCPI    = define_country_cpi(code: "th", iso3: "THA", label: "Thailand")
      SwedenCPI      = define_country_cpi(code: "se", iso3: "SWE", label: "Sweden")
      NorwayCPI      = define_country_cpi(code: "no", iso3: "NOR", label: "Norway")
      CzechiaCPI     = define_country_cpi(code: "cz", iso3: "CZE", label: "Czechia")
      HungaryCPI     = define_country_cpi(code: "hu", iso3: "HUN", label: "Hungary")
      IsraelCPI      = define_country_cpi(code: "il", iso3: "ISR", label: "Israel")
      PhilippinesCPI = define_country_cpi(code: "ph", iso3: "PHL", label: "Philippines")
      MalaysiaCPI    = define_country_cpi(code: "my", iso3: "MYS", label: "Malaysia")
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Tools::DataPipeline::IMF.run_vn_cpi
  Tools::DataPipeline::IMF.run_kr_cpi
  Tools::DataPipeline::IMF.run_cn_cpi
  Tools::DataPipeline::IMF.run_ru_cpi
  Tools::DataPipeline::IMF.run_ru_fx
end
