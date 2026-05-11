# frozen_string_literal: true

require_relative "data_loader"

module Timeprice
  # Enumerate bundled data sources with license/attribution and the actual
  # coverage range derived from data/ at runtime.
  module Sources
    # Static license & attribution metadata. Coverage is computed dynamically.
    ATTRIBUTIONS = [
      {
        id: "us_cpi",
        kind: "cpi",
        country: "US",
        name: "U.S. Bureau of Labor Statistics — CPI-U (series CUUR0000SA0)",
        license: "U.S. Government work — public domain",
        license_url: "https://www.bls.gov/bls/linksite.htm",
        attribution: "Data: U.S. Bureau of Labor Statistics"
      },
      {
        id: "uk_cpi",
        kind: "cpi",
        country: "UK",
        name: "UK Office for National Statistics — CPI all-items (series D7BT)",
        license: "Open Government Licence v3.0",
        license_url: "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
        attribution: "Contains public sector information licensed under the Open Government Licence v3.0"
      },
      {
        id: "eu_hicp",
        kind: "cpi",
        country: "EU",
        name: "Eurostat — HICP prc_hicp_midx (Euro area, all items)",
        license: "Eurostat reuse policy (free reuse with attribution)",
        license_url: "https://ec.europa.eu/eurostat/about-us/policies/copyright",
        attribution: "Source: Eurostat"
      },
      {
        id: "jp_cpi",
        kind: "cpi",
        country: "JP",
        name: "World Bank — FP.CPI.TOTL (annual, JP fallback)",
        license: "CC BY 4.0",
        license_url: "https://datacatalog.worldbank.org/public-licenses#cc-by",
        attribution: "Source: World Bank, FP.CPI.TOTL"
      },
      {
        id: "vn_cpi",
        kind: "cpi",
        country: "VN",
        name: "World Bank — FP.CPI.TOTL (annual)",
        license: "CC BY 4.0",
        license_url: "https://datacatalog.worldbank.org/public-licenses#cc-by",
        attribution: "Source: World Bank, FP.CPI.TOTL"
      },
      {
        id: "fx_ecb",
        kind: "fx",
        country: nil,
        name: "European Central Bank reference rates (via Frankfurter)",
        license: "ECB reference rates — free reuse",
        license_url: "https://www.ecb.europa.eu/services/disclaimer/html/index.en.html",
        attribution: "FX data: European Central Bank reference rates via Frankfurter"
      },
      {
        id: "fx_vnd",
        kind: "fx",
        country: "VN",
        name: "World Bank — PA.NUS.FCRF (VND annual average, broadcast daily)",
        license: "CC BY 4.0",
        license_url: "https://datacatalog.worldbank.org/public-licenses#cc-by",
        attribution: "VND FX: World Bank, PA.NUS.FCRF"
      }
    ].freeze

    module_function

    # Returns an array of hashes with :id, :kind, :name, :license, :license_url,
    # :attribution, :coverage (string like "1990-01 to 2026-03 (monthly+annual)").
    def list
      ATTRIBUTIONS.map { |s| s.merge(coverage: coverage_for(s)) }
    end

    def coverage_for(src)
      case src[:kind]
      when "cpi" then cpi_coverage(src[:country])
      when "fx"  then fx_coverage(src[:id])
      else "n/a"
      end
    rescue StandardError => e
      "(coverage unavailable: #{e.message})"
    end

    def cpi_coverage(country)
      data = DataLoader.load_cpi(country)
      monthly = (data["monthly"] || {}).keys.sort
      annual  = (data["annual"]  || {}).keys.sort
      parts = []
      parts << "monthly #{monthly.first}..#{monthly.last} (#{monthly.size})" unless monthly.empty?
      parts << "annual #{annual.first}..#{annual.last} (#{annual.size})" unless annual.empty?
      parts.join(", ")
    end

    def fx_coverage(id)
      root = File.join(DataLoader.data_root, "fx", "usd")
      years = Dir[File.join(root, "*.json")].map { |f| File.basename(f, ".json").to_i }.sort
      return "no data" if years.empty?
      case id
      when "fx_vnd"
        # VND broadcast-from-annual covers earlier years too.
        with_vnd = years.select do |y|
          d = JSON.parse(File.read(File.join(root, "#{y}.json")))
          d["rates"].any? { |_, v| v.key?("VND") }
        end
        return "no VND data" if with_vnd.empty?
        "USD↔VND #{with_vnd.first}..#{with_vnd.last}"
      else
        # ECB pairs (EUR/GBP/JPY) start 1999
        ecb_years = years.select do |y|
          d = JSON.parse(File.read(File.join(root, "#{y}.json")))
          d["rates"].any? { |_, v| (v.keys & %w[EUR GBP JPY]).any? }
        end
        return "no ECB data" if ecb_years.empty?
        "USD↔EUR/GBP/JPY daily #{ecb_years.first}..#{ecb_years.last}"
      end
    end
  end
end
