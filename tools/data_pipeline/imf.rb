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

      class VietnamCPI < CountryCPI
        ISO3 = "VNM"
        configure(
          country_code: "vn",
          country_label: "Vietnam",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class KoreaCPI < CountryCPI
        ISO3 = "KOR"
        configure(
          country_code: "kr",
          country_label: "Korea, Rep.",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class ChinaCPI < CountryCPI
        ISO3 = "CHN"
        configure(
          country_code: "cn",
          country_label: "China",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class RussiaCPI < CountryCPI
        ISO3 = "RUS"
        configure(
          country_code: "ru",
          country_label: "Russia",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class BrazilCPI < CountryCPI
        ISO3 = "BRA"
        configure(
          country_code: "br",
          country_label: "Brazil",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class IndiaCPI < CountryCPI
        ISO3 = "IND"
        configure(
          country_code: "in",
          country_label: "India",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class MexicoCPI < CountryCPI
        ISO3 = "MEX"
        configure(
          country_code: "mx",
          country_label: "Mexico",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class SwitzerlandCPI < CountryCPI
        ISO3 = "CHE"
        configure(
          country_code: "ch",
          country_label: "Switzerland",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class SingaporeCPI < CountryCPI
        ISO3 = "SGP"
        configure(
          country_code: "sg",
          country_label: "Singapore",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class HongKongCPI < CountryCPI
        ISO3 = "HKG"
        configure(
          country_code: "hk",
          country_label: "Hong Kong SAR, China",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end

      class NewZealandCPI < CountryCPI
        ISO3 = "NZL"
        configure(
          country_code: "nz",
          country_label: "New Zealand",
          source_label: "IMF Data Portal CPI dataflow (monthly) + World Bank FP.CPI.TOTL (annual)",
          default_base_year: "2010=100",
          log_label: "IMF",
          provider_id: "imf",
          priority: 40
        )
      end
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
