# frozen_string_literal: true

require_relative "_common"
require_relative "merge_policy"

module Sources
  # Owns one data/cpi/<code>.json file. Given the freshly-fetched series
  # from a Provider (today: single; later: a chain of providers), handles
  # drift detection, rebase renormalization, merge with the prior snapshot,
  # write to disk, and the per-source summary log.
  #
  # Extracted from Provider so a future multi-provider chain can drive a
  # single file write from multiple sources without each Provider re-opening
  # the file. For now Providers still call us with one (monthly, annual)
  # tuple — output is byte-identical to the prior implementation.
  class CountryFile
    def initialize(country_code:, country_label:, source_label:,
                   default_base_year:, log_label:)
      @country_code      = country_code
      @country_label     = country_label
      @source_label      = source_label
      @default_base_year = default_base_year
      @log_label         = log_label
    end

    def write_merged(monthly:, annual:, provider_id:)
      prior = load_prior
      base_year, prior_normalized = apply_drift(prior, monthly, annual)
      contribution = { monthly: monthly, annual: annual, provider_id: provider_id }
      merged = MergePolicy.layer(prior_normalized, contribution)
      write(base_year, merged, prior_normalized["providers"], provider_id)
      log_summary(merged: merged, incoming: contribution,
                  prior: { monthly: prior_normalized["monthly"], annual: prior_normalized["annual"] })
    end

    private

    attr_reader :country_code, :country_label, :source_label,
                :default_base_year, :log_label

    def path
      File.join(Sources::DATA_ROOT, "cpi", "#{country_code}.json")
    end

    def load_prior
      Sources.read_json_if_exists(path) || {}
    end

    # Returns [base_year, prior_normalized] where prior_normalized has the
    # same keys as prior but with monthly/annual rebased if the new series
    # indicates a rebase (drift >0.5% on shared periods).
    def apply_drift(prior, monthly, annual)
      prior_monthly = prior["monthly"] || {}
      prior_annual  = prior["annual"]  || {}
      base_year     = prior["base_year"] || default_base_year
      verdict, ratio = drift_check(prior_monthly, prior_annual, monthly, annual)
      return [base_year, prior] unless verdict == :rebase

      rebased = prior.merge(
        "monthly" => Sources.renormalize(prior_monthly, ratio),
        "annual" => Sources.renormalize(prior_annual, ratio)
      )
      ["rebased #{Sources.today}", rebased]
    end

    # Drift is most informative on whichever granularity has the most overlap.
    # Prefer monthly when the new series carries any; else annual.
    def drift_check(prior_monthly, prior_annual, monthly, annual)
      drift_prior, drift_new = monthly.any? ? [prior_monthly, monthly] : [prior_annual, annual]
      verdict, ratio, msg = Sources.cpi_drift_check(drift_prior, drift_new)
      Sources.log "#{log_label} drift: #{msg}"
      Sources.log "#{log_label}: rebase — renormalizing prior by ratio #{ratio}" if verdict == :rebase
      [verdict, ratio]
    end

    def write(base_year, merged, prior_providers, provider_id)
      Sources.write_json(path, {
                           "schema_version" => 1,
                           "country" => country_code.upcase,
                           "base_year" => base_year,
                           "source" => source_label,
                           "updated_at" => Sources.today,
                           "monthly" => merged[:monthly],
                           "annual" => merged[:annual],
                           "provenance" => merged[:provenance],
                           "providers" => provider_entries(prior_providers, provider_id),
                         })
    end

    # Maintains the file-level providers[] list: keeps prior entries for
    # other providers in the chain, refreshes this provider's entry.
    def provider_entries(prior_providers, provider_id)
      others = (prior_providers || []).reject { |p| p["id"] == provider_id }
      others + [{
        "id" => provider_id,
        "label" => source_label,
        "fetched_at" => Sources.today,
        "status" => "ok",
      }]
    end

    def log_summary(merged:, incoming:, prior:)
      new_points = (incoming[:monthly].keys - prior[:monthly].keys).size +
                   (incoming[:annual].keys - prior[:annual].keys).size
      range = (merged[:monthly].any? ? merged[:monthly] : merged[:annual]).keys.minmax
      Sources.log "#{log_label}(#{country_label}): #{merged[:monthly].size} monthly + " \
                  "#{merged[:annual].size} annual data points, range #{range.first}..#{range.last}, " \
                  "#{new_points} new since last run."
    end
  end
end
