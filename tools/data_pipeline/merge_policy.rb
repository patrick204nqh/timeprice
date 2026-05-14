# frozen_string_literal: true

require_relative "namespace"

module Tools
  module DataPipeline
    # Pure functions for layering a new provider's contribution onto a prior
    # snapshot, recording per-period provenance, and returning the merged
    # result. No I/O — easy to unit test.
    #
    # Today only one provider contributes per file (single-element chain), so
    # "merge" is "new wins on conflicts, every new key is tagged with the new
    # provider's id". A future expansion will accept multiple providers in
    # priority order; the contract here is shaped to absorb that change.
    module MergePolicy
      SERIES = %w[monthly quarterly annual].freeze

      module_function

      # @param prior [Hash] { "monthly" => {...}, "quarterly" => {...}, "annual" => {...},
      #                       "provenance" => {"monthly"=>{...}, "quarterly"=>{...}, "annual"=>{...}} }
      # @param contribution [Hash] { monthly:, quarterly:, annual:, provider_id: }
      # @return [Hash] { monthly:, quarterly:, annual:, provenance: }
      def layer(prior, contribution)
        prior_provenance = prior["provenance"] || empty_provenance

        result = { provenance: {} }
        SERIES.each do |s|
          prior_series = prior[s] || {}
          incoming = contribution[s.to_sym] || {}
          result[s.to_sym] = prior_series.merge(incoming)
          result[:provenance][s] = tag(prior_provenance[s] || {}, incoming, contribution[:provider_id])
        end
        result
      end

      # @return [Hash] prior provenance with `provider_id` recorded for every
      #   period present in `new_series`. Untouched periods keep their prior tag.
      def tag(prior_provenance, new_series, provider_id)
        stamped = new_series.keys.to_h { |k| [k, provider_id] }
        prior_provenance.merge(stamped)
      end

      def empty_provenance
        SERIES.to_h { |s| [s, {}] }
      end
    end
  end
end
