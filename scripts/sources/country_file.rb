# frozen_string_literal: true

require_relative "_common"
require_relative "merge_policy"
require_relative "provenance"

module Sources
  # Owns one data/cpi/<code>.json file. Given the freshly-fetched series
  # from a Provider (today: single; later: a chain of providers), handles
  # drift detection, rebase renormalization, merge with the prior snapshot,
  # write to disk, and the per-source summary log.
  #
  # Extracted from Provider so a future multi-provider chain can drive a
  # single file write from multiple sources without each Provider re-opening
  # the file. For now Providers still call us with one (monthly, quarterly,
  # annual) tuple — output is byte-identical to the prior implementation
  # whenever a quarterly series is absent.
  class CountryFile
    SCHEMA_VERSION = 4

    def initialize(country_code:, country_label:, source_label:,
                   default_base_year:, log_label:)
      @country_code      = country_code
      @country_label     = country_label
      @source_label      = source_label
      @default_base_year = default_base_year
      @log_label         = log_label
    end

    def write_merged(monthly:, annual:, provider_id:, quarterly: {})
      prior = load_prior
      # On-disk provenance is a compact range list; MergePolicy works on a
      # per-period hash, so expand on read and compact on write.
      prior_expanded = prior.merge("provenance" => Provenance.expand(prior["provenance"]))
      base_year, prior_normalized = apply_drift(prior_expanded, monthly, quarterly, annual)
      contribution = {
        monthly: monthly, quarterly: quarterly, annual: annual,
        provider_id: provider_id
      }
      merged = MergePolicy.layer(prior_normalized, contribution)
      write(base_year, merged, prior_normalized["providers"], provider_id)
      log_summary(merged: merged, incoming: contribution,
                  prior: {
                    monthly: prior_normalized["monthly"],
                    quarterly: prior_normalized["quarterly"],
                    annual: prior_normalized["annual"],
                  })
    end

    private

    attr_reader :country_code, :country_label, :source_label,
                :default_base_year, :log_label

    def path
      File.join(Sources::DATA_ROOT, "cpi", "#{country_code}.json")
    end

    # Read the on-disk v3/v4 CPI file (if present) into MergePolicy's internal
    # flat shape so the rest of the writer doesn't have to know about the
    # nested layout. Returns {} on first run.
    def load_prior
      disk = Sources.read_json_if_exists(path) || {}
      return {} if disk.empty?

      {
        "monthly" => disk.dig("series", "monthly") || {},
        "quarterly" => disk.dig("series", "quarterly") || {},
        "annual" => disk.dig("series", "annual") || {},
        "base_year" => deserialise_base_year(disk["index"]),
        "provenance" => disk["provenance"],
        "providers" => disk["providers"],
      }
    end

    def deserialise_base_year(index)
      return nil unless index.is_a?(Hash)

      period = index["base_period"]
      rebased = index["rebased_at"]
      return nil if period.nil?

      rebased ? "#{period}=100 (rebased #{rebased})" : "#{period}=100"
    end

    # Returns [base_year, prior_normalized] where prior_normalized has the
    # same keys as prior but with series rebased if the new series indicates
    # a rebase (drift >0.5% on shared periods).
    def apply_drift(prior, monthly, quarterly, annual)
      prior_series = {
        monthly: prior["monthly"] || {},
        quarterly: prior["quarterly"] || {},
        annual: prior["annual"] || {},
      }
      new_series = { monthly: monthly, quarterly: quarterly, annual: annual }
      base_year  = prior["base_year"] || default_base_year
      verdict, ratio = drift_check(prior_series, new_series)
      return [base_year, prior] unless verdict == :rebase

      rebased = prior.merge(
        "monthly" => Sources.renormalize(prior_series[:monthly], ratio),
        "quarterly" => Sources.renormalize(prior_series[:quarterly], ratio),
        "annual" => Sources.renormalize(prior_series[:annual], ratio)
      )
      original_ref = base_year.to_s.sub(/\s*\(rebased [^)]+\)\s*\z/, "")
      ["#{original_ref} (rebased #{Sources.today})", rebased]
    end

    # Pick the highest-granularity shared series for drift detection.
    def drift_check(prior_series, new_series)
      key = if new_series[:monthly].any? then :monthly
            elsif new_series[:quarterly].any? then :quarterly
            else :annual
            end
      verdict, ratio, msg = Sources.cpi_drift_check(prior_series[key], new_series[key])
      Sources.log "#{log_label} drift: #{msg}"
      Sources.log "#{log_label}: rebase — renormalizing prior by ratio #{ratio}" if verdict == :rebase
      [verdict, ratio]
    end

    def write(base_year, merged, prior_providers, provider_id)
      series = {
        "monthly" => merged[:monthly],
        "annual" => merged[:annual],
      }
      # Only emit the quarterly block when there is data, so files for
      # monthly+annual countries stay byte-identical to schema v3 layout
      # (other than the schema_version bump).
      series["quarterly"] = merged[:quarterly] if merged[:quarterly]&.any?

      Sources.write_json(path, {
                           "schema_version" => SCHEMA_VERSION,
                           "country" => country_code.upcase,
                           "index" => serialise_base_year(base_year),
                           "series" => series,
                           "provenance" => Provenance.compact(merged[:provenance]),
                           "providers" => provider_entries(prior_providers, provider_id),
                         })
    end

    def serialise_base_year(str)
      m = Sources::BASE_YEAR_RE.match(str.to_s)
      if m
        { "base_period" => m[:period], "rebased_at" => m[:rebased] }
      else
        Sources.log "WARN: unrecognised base_year #{str.inspect} — preserving as-is"
        { "base_period" => str.to_s, "rebased_at" => nil }
      end
    end

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
                   ((incoming[:quarterly] || {}).keys - (prior[:quarterly] || {}).keys).size +
                   (incoming[:annual].keys - prior[:annual].keys).size
      pick = if merged[:monthly].any?
               merged[:monthly]
             elsif merged[:quarterly]&.any?
               merged[:quarterly]
             else
               merged[:annual]
             end
      range = pick.keys.minmax
      parts = ["#{merged[:monthly].size} monthly"]
      parts << "#{merged[:quarterly].size} quarterly" if merged[:quarterly]&.any?
      parts << "#{merged[:annual].size} annual"
      Sources.log "#{log_label}(#{country_label}): #{parts.join(" + ")} data points, " \
                  "range #{range.first}..#{range.last}, #{new_points} new since last run."
    end
  end
end
