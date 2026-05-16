# frozen_string_literal: true

require_relative "namespace"

require_relative "_common"

module Tools
  module DataPipeline
    # Scans the data/ tree and writes data/manifest.json — the single source of
    # truth for what is bundled. Called as the final step of update_data.rb,
    # after all CPI / FX writers have run.
    #
    # Derived from disk state, so it stays in sync with whatever the fetchers
    # actually produced. Re-running is idempotent.
    module Manifest
      module_function

      def write
        countries = cpi_countries
        daily_years = fx_daily_years
        currencies = fx_currencies(daily_years)
        daily_min, daily_max = fx_daily_bounds(daily_years)

        data = {
          "schema_version" => 4,
          "generated_at" => Tools::DataPipeline.today,
          "countries" => countries,
          "fx" => {
            "base" => "USD",
            "currencies" => currencies,
            "daily_years" => daily_years,
            "daily_min" => daily_min,
            "daily_max" => daily_max,
            "annual_file" => "fx/usd/_annual.json",
          },
        }
        path = File.join(Tools::DataPipeline::DATA_ROOT, "manifest.json")
        Tools::DataPipeline.write_json(path, data)
        Tools::DataPipeline.log "Manifest: #{countries.size} countries, #{daily_years.size} fx years."
      end

      def cpi_countries
        Dir[File.join(Tools::DataPipeline::DATA_ROOT, "cpi", "*.json")].map do |path|
          cpi = JSON.parse(File.read(path))
          Timeprice::Schema.load_cpi(cpi, path: path)

          code = cpi["country"]
          series = cpi["series"] || {}
          grans = []
          ranges = {}
          %w[monthly quarterly annual].each do |gran|
            points = series[gran] || {}
            next unless points.is_a?(Hash) && points.any?

            grans << gran
            keys = points.keys.sort
            ranges[gran] = { "min" => keys.first, "max" => keys.last }
          end

          if grans.empty?
            fail ValidationError, "manifest: #{path} has no non-empty series — refusing to emit a degenerate manifest entry"
          end

          {
            "code" => code,
            "currency" => Tools::DataPipeline::COUNTRY_TO_CURRENCY.fetch(code),
            "cpi_file" => "cpi/#{File.basename(path)}",
            "granularities" => grans,
            "cpi_ranges" => ranges,
          }
        end
      end

      def fx_daily_bounds(daily_years)
        return [nil, nil] if daily_years.empty?

        first = JSON.parse(File.read(File.join(Tools::DataPipeline::DATA_ROOT, "fx", "usd", "#{daily_years.min}.json")))
        last  = JSON.parse(File.read(File.join(Tools::DataPipeline::DATA_ROOT, "fx", "usd", "#{daily_years.max}.json")))
        [(first["rates"] || {}).keys.min, (last["rates"] || {}).keys.max]
      end

      def fx_daily_years
        Dir[File.join(Tools::DataPipeline::DATA_ROOT, "fx", "usd", "*.json")]
          .reject { |p| File.basename(p) == "_annual.json" }
          .map { |p| File.basename(p, ".json").to_i }
          .sort
      end

      def fx_currencies(daily_years)
        seen = []
        daily_years.each do |y|
          data = JSON.parse(File.read(File.join(Tools::DataPipeline::DATA_ROOT, "fx", "usd", "#{y}.json")))
          (data["rates"] || {}).each_value { |day| seen.concat(day.keys) }
        end
        annual_path = File.join(Tools::DataPipeline::DATA_ROOT, "fx", "usd", "_annual.json")
        if File.exist?(annual_path)
          data = JSON.parse(File.read(annual_path))
          (data["annual"] || {}).each_value { |yh| seen.concat(yh.keys) }
        end
        seen.uniq.sort
      end
    end
  end
end
