# frozen_string_literal: true

require_relative "_common"

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

    def write_merged(monthly:, annual:)
      prior = load_prior
      base_year, prior_monthly, prior_annual = apply_drift(prior, monthly, annual)
      merged = { monthly: prior_monthly.merge(monthly), annual: prior_annual.merge(annual) }
      write(base_year, merged[:monthly], merged[:annual])
      log_summary(merged: merged, incoming: { monthly: monthly, annual: annual },
                  prior: { monthly: prior_monthly, annual: prior_annual })
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

    # Returns [base_year, prior_monthly, prior_annual] — renormalizing prior
    # if the new series indicates a rebase (drift >0.5% on shared periods).
    def apply_drift(prior, monthly, annual)
      prior_monthly = prior["monthly"] || {}
      prior_annual  = prior["annual"]  || {}
      base_year     = prior["base_year"] || default_base_year
      verdict, ratio = drift_check(prior_monthly, prior_annual, monthly, annual)
      return [base_year, prior_monthly, prior_annual] unless verdict == :rebase

      [
        "rebased #{Sources.today}",
        Sources.renormalize(prior_monthly, ratio),
        Sources.renormalize(prior_annual, ratio),
      ]
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

    def write(base_year, merged_monthly, merged_annual)
      Sources.write_json(path, {
                           "schema_version" => 1,
                           "country" => country_code.upcase,
                           "base_year" => base_year,
                           "source" => source_label,
                           "updated_at" => Sources.today,
                           "monthly" => merged_monthly,
                           "annual" => merged_annual,
                         })
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
