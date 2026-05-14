# frozen_string_literal: true

require_relative "namespace"

require_relative "_common"
require_relative "merge_policy"
require_relative "provenance"

module Tools
  module DataPipeline
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
      def initialize(country_code:, country_label:, source_label:,
                     default_base_year:, log_label:)
        @country_code      = country_code
        @country_label     = country_label
        @source_label      = source_label
        @default_base_year = default_base_year
        @log_label         = log_label
      end

      def write_merged(series:, provider_id:)
        prior = load_prior
        # On-disk provenance is a compact range list; MergePolicy works on a
        # per-period hash, so expand on read and compact on write.
        prior_expanded = prior.merge("provenance" => Provenance.expand(prior["provenance"]))
        base_year, prior_normalized = apply_drift(prior_expanded, series)
        contribution = {
          monthly: series.monthly, quarterly: series.quarterly, annual: series.annual,
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
        File.join(Tools::DataPipeline::DATA_ROOT, "cpi", "#{country_code}.json")
      end

      # Read the on-disk v3/v4 CPI file (if present) into MergePolicy's internal
      # flat shape so the rest of the writer doesn't have to know about the
      # nested layout. On first run (no file yet) every series key is an empty
      # hash — downstream code can rely on `prior["monthly"]` etc. being
      # iterable without nil guards.
      def load_prior
        disk = Tools::DataPipeline.read_json_if_exists(path) || {}
        {
          "monthly" => disk.dig("series", "monthly") || {},
          "quarterly" => disk.dig("series", "quarterly") || {},
          "annual" => disk.dig("series", "annual") || {},
          "base_year" => Timeprice::Schema.deserialise_base_year(disk["index"]),
          "provenance" => disk["provenance"],
          "providers" => disk["providers"],
        }
      end

      # Returns [base_year, prior_normalized] where prior_normalized has the
      # same keys as prior but with series rebased if the new series indicates
      # a rebase (drift >0.5% on shared periods).
      def apply_drift(prior, series)
        prior_series = {
          monthly: prior["monthly"] || {},
          quarterly: prior["quarterly"] || {},
          annual: prior["annual"] || {},
        }
        new_series = { monthly: series.monthly, quarterly: series.quarterly, annual: series.annual }
        base_year  = prior["base_year"] || default_base_year
        verdict, ratio = drift_check(prior_series, new_series)
        return [base_year, prior] unless verdict == :rebase

        rebased = prior.merge(
          "monthly" => Tools::DataPipeline.renormalize(prior_series[:monthly], ratio),
          "quarterly" => Tools::DataPipeline.renormalize(prior_series[:quarterly], ratio),
          "annual" => Tools::DataPipeline.renormalize(prior_series[:annual], ratio)
        )
        original_ref = base_year.to_s.sub(/\s*\(rebased [^)]+\)\s*\z/, "")
        ["#{original_ref} (rebased #{Tools::DataPipeline.today})", rebased]
      end

      # Pick the highest-granularity shared series for drift detection.
      def drift_check(prior_series, new_series)
        key = if new_series[:monthly].any? then :monthly
              elsif new_series[:quarterly].any? then :quarterly
              else :annual
              end
        verdict, ratio, msg = Tools::DataPipeline.cpi_drift_check(prior_series[key], new_series[key])
        Tools::DataPipeline.log "#{log_label} drift: #{msg}"
        Tools::DataPipeline.log "#{log_label}: rebase — renormalizing prior by ratio #{ratio}" if verdict == :rebase
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

        Tools::DataPipeline.write_json(path, {
                                         Timeprice::Schema::KEY_SCHEMA_VERSION => Timeprice::Schema::CURRENT_VERSION,
                                         Timeprice::Schema::KEY_COUNTRY => country_code.upcase,
                                         Timeprice::Schema::KEY_INDEX => serialise_base_year(base_year),
                                         Timeprice::Schema::KEY_SERIES => series,
                                         Timeprice::Schema::KEY_PROVENANCE => Provenance.compact(merged[:provenance]),
                                         Timeprice::Schema::KEY_PROVIDERS => provider_entries(prior_providers, provider_id),
                                       })
      end

      def serialise_base_year(str)
        result = Timeprice::Schema.serialise_base_year(str)
        unless Timeprice::Schema::BASE_YEAR_RE.match?(str.to_s)
          Tools::DataPipeline.log "WARN: unrecognised base_year #{str.inspect} — preserving as-is"
        end
        result
      end

      def provider_entries(prior_providers, provider_id)
        others = (prior_providers || []).reject { |p| p["id"] == provider_id }
        others + [{
          "id" => provider_id,
          "label" => source_label,
          "fetched_at" => Tools::DataPipeline.today,
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
        Tools::DataPipeline.log "#{log_label}(#{country_label}): #{parts.join(" + ")} data points, " \
                                "range #{range.first}..#{range.last}, #{new_points} new since last run."
      end
    end
  end
end
