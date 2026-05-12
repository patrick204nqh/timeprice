# frozen_string_literal: true

require_relative "_common"

module Sources
  # Owns one data/fx/usd/<year>.json file in schema v3 — daily rates only.
  # Annual fallback rates (VND today) live in data/fx/usd/_annual.json,
  # written via Sources::FxAnnualFile.
  class FxYearFile
    def initialize(year)
      @year = year.to_i
    end

    def write_daily(rates_by_date:, provider_id:, source_label:)
      prior = load_prior
      merged_rates = (prior["rates"] || {}).merge(rates_by_date) do |_date, old_v, new_v|
        old_v.merge(new_v)
      end

      dates_sorted = merged_rates.keys.sort
      daily_currencies = merged_rates.values.flat_map(&:keys).uniq.sort

      data = {
        "schema_version" => 4,
        "base" => "USD",
        "year" => year,
        "rates" => merged_rates,
        "provenance" => [{
          "series" => "daily",
          "currencies" => daily_currencies,
          "from" => dates_sorted.first,
          "to" => dates_sorted.last,
          "provider" => provider_id,
        }],
        "providers" => [{
          "id" => provider_id,
          "label" => source_label,
          "fetched_at" => Sources.today,
          "status" => "ok",
        }],
      }
      Sources.write_json(path, data)
      merged_rates
    end

    private

    attr_reader :year

    def path
      File.join(Sources::DATA_ROOT, "fx", "usd", "#{year}.json")
    end

    def load_prior
      Sources.read_json_if_exists(path) || {}
    end
  end

  # Owns data/fx/usd/_annual.json — the single source of truth for USD-base
  # annual FX rates across all years (today only VND from World Bank).
  class FxAnnualFile
    PATH_REL = "fx/usd/_annual.json"

    def self.path
      File.join(Sources::DATA_ROOT, PATH_REL)
    end

    # @param annual_by_year_currency [Hash<String, Hash<String, Float>>]
    #   e.g. { "1990" => { "VND" => 6537.6 }, ... }
    #
    # Multi-provider behavior: `_annual.json` is shared across all annual-FX
    # providers (today: WB → VND, IMF → RUB). Each call merges per-year-per-
    # currency and rewrites only its own provenance entry — other providers'
    # provenance and `providers` entries are preserved. Per-currency-per-
    # provider attribution lives in the provenance array (`currencies` field).
    def self.write(annual_by_year_currency:, provider_id:, source_label:)
      prior = Sources.read_json_if_exists(path) || {}
      merged = (prior["annual"] || {}).dup
      annual_by_year_currency.each do |year, ccy_hash|
        merged[year] = (merged[year] || {}).merge(ccy_hash)
      end

      own_currencies = annual_by_year_currency.values.flat_map(&:keys).uniq.sort
      own_years_sorted = annual_by_year_currency.keys.map(&:to_i).sort
      other_provenance = (prior["provenance"] || []).reject { |p| p["provider"] == provider_id }
      other_providers = (prior["providers"] || []).reject { |p| p["id"] == provider_id }

      data = {
        "schema_version" => 4,
        "base" => "USD",
        "annual" => merged,
        "provenance" => other_provenance + [
          {
            "series" => "annual",
            "currencies" => own_currencies,
            "from" => own_years_sorted.first.to_s,
            "to" => own_years_sorted.last.to_s,
            "provider" => provider_id,
          },
        ],
        "providers" => other_providers + [{
          "id" => provider_id,
          "label" => source_label,
          "fetched_at" => Sources.today,
          "status" => "ok",
        }],
      }
      Sources.write_json(path, data)
    end
  end
end
