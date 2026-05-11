# frozen_string_literal: true

require_relative "_common"

module Sources
  # Owns one data/fx/usd/<year>.json file in schema v3.
  #
  # Accepts contributions of two shapes:
  #   - `{ daily: { "YYYY-MM-DD" => { "EUR" => Float, ... } }, provider_id:, source_label: }`
  #   - `{ annual: { "VND" => Float }, provider_id:, source_label: }`
  #
  # Merges with whatever is already on disk, refreshes the contributing
  # provider's entry in the providers[] list while preserving other providers'
  # entries (so a Frankfurter refresh does not clobber World Bank's annual
  # contribution and vice versa), and rewrites provenance.
  #
  # Provenance is regenerated from the merged data on every write — derived
  # state, not maintained-in-place, so the on-disk file is always consistent
  # with its own data blocks.
  class FxYearFile
    def initialize(year)
      @year = year.to_i
    end

    def write_daily(rates_by_date:, provider_id:, source_label:)
      prior = load_prior
      merged_rates = (prior["rates"] || {}).merge(rates_by_date) do |_date, old_v, new_v|
        old_v.merge(new_v)
      end
      write(rates: merged_rates,
            annual: prior["annual"] || {},
            provider_id: provider_id,
            source_label: source_label,
            prior_providers: prior["providers"] || [])
      merged_rates
    end

    def write_annual(annual_by_currency:, provider_id:, source_label:)
      prior = load_prior
      merged_annual = (prior["annual"] || {}).merge(annual_by_currency)
      write(rates: prior["rates"] || {},
            annual: merged_annual,
            provider_id: provider_id,
            source_label: source_label,
            prior_providers: prior["providers"] || [])
    end

    private

    attr_reader :year

    def path
      File.join(Sources::DATA_ROOT, "fx", "usd", "#{year}.json")
    end

    def load_prior
      Sources.read_json_if_exists(path) || {}
    end

    def write(rates:, annual:, provider_id:, source_label:, prior_providers:)
      data = {
        "schema_version" => 3,
        "base" => "USD",
        "year" => year,
        "rates" => rates,
        "provenance" => build_provenance(rates, annual),
        "providers" => provider_entries(prior_providers, provider_id, source_label)
      }
      data["annual"] = annual if annual.any?
      Sources.write_json(path, data)
    end

    def build_provenance(rates, annual)
      out = []
      if rates.any?
        dates_sorted = rates.keys.sort
        daily_currencies = rates.values.flat_map(&:keys).uniq.sort
        out << {
          "series" => "daily",
          "currencies" => daily_currencies,
          "from" => dates_sorted.first,
          "to" => dates_sorted.last,
          "provider" => "frankfurter"
        }
      end
      if annual.any?
        out << {
          "series" => "annual",
          "currencies" => annual.keys.sort,
          "year" => year,
          "provider" => "world_bank"
        }
      end
      out
    end

    # Refresh the contributing provider's entry; keep prior entries for other
    # providers in the chain.
    def provider_entries(prior_providers, provider_id, source_label)
      others = (prior_providers || []).reject { |p| p["id"] == provider_id }
      others + [{
        "id" => provider_id,
        "label" => source_label,
        "fetched_at" => Sources.today,
        "status" => "ok"
      }]
    end
  end

  # Owns data/fx/_annual.json — the sparse fallback for years that predate
  # daily FX coverage (pre-1999, today only VND from World Bank).
  class FxAnnualFile
    PATH_REL = "fx/_annual.json"

    def self.path
      File.join(Sources::DATA_ROOT, PATH_REL)
    end

    # @param annual_by_year_currency [Hash<String, Hash<String, Float>>]
    #   e.g. { "1990" => { "VND" => 6537.6 }, ... }
    def self.write(annual_by_year_currency:, provider_id:, source_label:)
      prior = Sources.read_json_if_exists(path) || {}
      merged = (prior["annual"] || {}).dup
      annual_by_year_currency.each do |year, ccy_hash|
        merged[year] = (merged[year] || {}).merge(ccy_hash)
      end

      years_sorted = merged.keys.map(&:to_i).sort
      all_currencies = merged.values.flat_map(&:keys).uniq.sort
      others = (prior["providers"] || []).reject { |p| p["id"] == provider_id }

      data = {
        "schema_version" => 3,
        "base" => "USD",
        "annual" => merged,
        "provenance" => [
          {
            "series" => "annual",
            "currencies" => all_currencies,
            "from" => years_sorted.first.to_s,
            "to" => years_sorted.last.to_s,
            "provider" => provider_id
          }
        ],
        "providers" => others + [{
          "id" => provider_id,
          "label" => source_label,
          "fetched_at" => Sources.today,
          "status" => "ok"
        }]
      }
      Sources.write_json(path, data)
    end
  end
end
