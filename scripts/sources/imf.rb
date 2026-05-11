# frozen_string_literal: true

require_relative "provider"
require_relative "fx_year_file"

# IMF Data Portal (api.imf.org), SDMX 2.1.
#
# Public endpoint, no API key. Provides three things this gem leans on:
#
#   * Monthly CPI all-items (CPI dataflow, key COUNTRY.CPI._T.IX.M):
#     - VN (primary monthly source on top of World Bank annual baseline)
#     - KR (primary monthly source on top of World Bank annual baseline)
#     - CN (primary monthly source on top of World Bank annual baseline)
#     - RU (primary monthly source on top of World Bank annual baseline)
#
#   * RUB/USD exchange rate (IFS dataflow, key M.RUS.ENDA_XDC_USD_RATE).
#     Frankfurter dropped RUB after the ECB suspended reference rates in
#     March 2022; we use IMF IFS period-average rates throughout for
#     consistency, written to _annual.json (annual mean of the 12 monthly
#     observations in each complete year).
#
# Historical note: the original IMF SDMX service at dataservices.imf.org
# (SDMX_JSON.svc/IFS) was decommissioned in 2025 when the new IMF Data
# Portal launched. The CPI dataflow on the new portal replaces what was
# previously the M.<COUNTRY>.PCPI_IX key on the IFS dataflow.
module Sources
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
      monthly = fetch_ifs_monthly("RUS", "ENDA_XDC_USD_RATE")
      annual  = derive_annual(monthly)
      Sources.validate_positive_numeric!(annual, "IMF RUB/USD annual")

      payload = annual.to_h { |year, rate| [year.to_s, { "RUB" => rate.round(4) }] }
      Sources::FxAnnualFile.write(
        annual_by_year_currency: payload,
        provider_id: "imf",
        source_label: "IMF IFS dataflow ENDA_XDC_USD_RATE (period-average, annual mean)"
      )

      Sources.log "IMF(RUB FX): #{annual.size} annual averages into _annual.json, " \
                  "range #{annual.keys.minmax.join("..")}."
    end

    def fetch_cpi_monthly(country_iso3)
      key  = "#{country_iso3}.CPI._T.IX.M"
      url  = "#{BASE_URL}/data/CPI/#{key}?startPeriod=1990-01"
      body = Sources.http_json(url, headers: { "Accept" => "application/json" })
      time_periods = extract_time_periods(body)
      parse_observations(body, time_periods)
    end

    # IFS exchange-rate series. INDICATOR is e.g. "ENDA_XDC_USD_RATE"
    # (period-average, domestic currency per USD).
    def fetch_ifs_monthly(country_iso3, indicator)
      key  = "M.#{country_iso3}.#{indicator}"
      url  = "#{BASE_URL}/data/IFS/#{key}?startPeriod=1990-01"
      body = Sources.http_json(url, headers: { "Accept" => "application/json" })
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
    # World Bank for every country, e-Stat for JP).
    class CountryCPI < Sources::Provider
      def self.iso3 = self::ISO3

      def fetch
        monthly = IMF.fetch_cpi_monthly(self.class.iso3)
        annual  = IMF.derive_annual(monthly)
        [monthly, annual]
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
        provider_id: "imf"
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
        provider_id: "imf"
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
        provider_id: "imf"
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
        provider_id: "imf"
      )
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Sources::IMF.run_vn_cpi
  Sources::IMF.run_kr_cpi
  Sources::IMF.run_cn_cpi
  Sources::IMF.run_ru_cpi
  Sources::IMF.run_ru_fx
end
