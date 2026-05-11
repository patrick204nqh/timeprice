# frozen_string_literal: true

require "json"
require_relative "../data_loader"

module Timeprice
  module Sources
    # Computes coverage strings for bundled data sources at runtime. All
    # filesystem reads happen here so the Sources attribution registry stays
    # a pure data table.
    module Coverage
      module_function

      # @param src [Hash] one entry from Sources::ATTRIBUTIONS
      # @return [String]
      def for(src)
        case src[:kind]
        when "cpi" then cpi(src[:country])
        when "fx"  then fx(src[:id])
        else "n/a"
        end
      rescue StandardError => e
        "(coverage unavailable: #{e.message})"
      end

      def cpi(country)
        data = DataLoader.load_cpi(country)
        monthly = (data["monthly"] || {}).keys.sort
        annual  = (data["annual"]  || {}).keys.sort
        parts = []
        parts << "monthly #{monthly.first}..#{monthly.last} (#{monthly.size})" unless monthly.empty?
        parts << "annual #{annual.first}..#{annual.last} (#{annual.size})" unless annual.empty?
        parts.join(", ")
      end

      def fx(id)
        years = fx_years
        return "no data" if years.empty?

        id == "fx_vnd" ? vnd_summary(years) : ecb_summary(years)
      end

      def fx_years
        Dir[File.join(fx_root, "*.json")].map { |f| File.basename(f, ".json").to_i }.sort
      end

      def vnd_summary(years)
        with_vnd = years.select { |y| year_has_currency?(y, %w[VND]) }
        return "no VND data" if with_vnd.empty?

        "USD↔VND #{with_vnd.first}..#{with_vnd.last}"
      end

      def ecb_summary(years)
        ecb_years = years.select { |y| year_has_currency?(y, %w[EUR GBP JPY]) }
        return "no ECB data" if ecb_years.empty?

        "USD↔EUR/GBP/JPY daily #{ecb_years.first}..#{ecb_years.last}"
      end

      def year_has_currency?(year, codes)
        rates = JSON.parse(File.read(File.join(fx_root, "#{year}.json")))["rates"]
        rates.any? { |_, v| v.keys.intersect?(codes) }
      end

      def fx_root
        File.join(DataLoader.data_root, "fx", "usd")
      end
    end
  end
end
