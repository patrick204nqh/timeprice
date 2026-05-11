# frozen_string_literal: true

require "json"
require_relative "../data_loader"

module Timeprice
  module Sources
    # Computes coverage strings for bundled data sources at runtime by reading
    # the structured `provenance` blocks in v3 data files. The Sources
    # attribution registry stays a pure data table; Coverage is the only
    # place that touches the filesystem.
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
        monthly = data.dig("series", "monthly") || {}
        annual  = data.dig("series", "annual") || {}
        parts = []
        parts << "monthly #{monthly.keys.min}..#{monthly.keys.max} (#{monthly.size})" if monthly.any?
        parts << "annual #{annual.keys.min}..#{annual.keys.max} (#{annual.size})" if annual.any?
        parts.join(", ")
      end

      def fx(id)
        case id
        when "fx_ecb" then ecb_summary
        when "fx_vnd" then vnd_summary
        else "n/a"
        end
      end

      # Frankfurter (ECB) → daily EUR/GBP/JPY in per-year files. Range derived
      # from the manifest's `daily_years` list.
      def ecb_summary
        years = DataLoader.load_manifest.dig("fx", "daily_years") || []
        return "no ECB data" if years.empty?

        "USD↔EUR/GBP/JPY daily #{years.first}..#{years.last}"
      end

      # All annual FX (today only VND) lives in data/fx/usd/_annual.json.
      def vnd_summary
        fallback = DataLoader.load_fx_annual_fallback
        years = (fallback&.dig("annual") || {})
                .select { |_y, ccy_hash| ccy_hash.key?("VND") }
                .keys.map(&:to_i).sort
        return "no VND data" if years.empty?

        "USD↔VND #{years.first}..#{years.last}"
      end
    end
  end
end
