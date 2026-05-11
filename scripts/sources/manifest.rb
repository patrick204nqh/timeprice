# frozen_string_literal: true

require_relative "_common"

module Sources
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

      data = {
        "schema_version" => 3,
        "generated_at" => Sources.today,
        "countries" => countries,
        "fx" => {
          "base" => "USD",
          "currencies" => currencies,
          "daily_years" => daily_years,
          "annual_file" => "fx/_annual.json",
        },
      }
      path = File.join(Sources::DATA_ROOT, "manifest.json")
      Sources.write_json(path, data)
      Sources.log "Manifest: #{countries.size} countries, #{daily_years.size} fx years."
    end

    def cpi_countries
      Dir[File.join(Sources::DATA_ROOT, "cpi", "*.json")].map do |path|
        cpi = JSON.parse(File.read(path))
        code = cpi["country"]
        grans = []
        grans << "monthly" if (cpi.dig("series", "monthly") || {}).any?
        grans << "annual"  if (cpi.dig("series", "annual")  || {}).any?
        {
          "code" => code,
          "currency" => Sources::COUNTRY_TO_CURRENCY.fetch(code),
          "cpi_file" => "cpi/#{File.basename(path)}",
          "granularities" => grans,
        }
      end
    end

    def fx_daily_years
      Dir[File.join(Sources::DATA_ROOT, "fx", "usd", "*.json")]
        .map { |p| File.basename(p, ".json").to_i }
        .sort
    end

    def fx_currencies(daily_years)
      seen = []
      daily_years.each do |y|
        data = JSON.parse(File.read(File.join(Sources::DATA_ROOT, "fx", "usd", "#{y}.json")))
        (data["rates"] || {}).each_value { |day| seen.concat(day.keys) }
        seen.concat((data["annual"] || {}).keys)
      end
      annual_path = File.join(Sources::DATA_ROOT, "fx", "_annual.json")
      if File.exist?(annual_path)
        data = JSON.parse(File.read(annual_path))
        (data["annual"] || {}).each_value { |yh| seen.concat(yh.keys) }
      end
      seen.uniq.sort
    end
  end
end
