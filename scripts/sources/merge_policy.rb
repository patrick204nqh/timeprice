# frozen_string_literal: true

module Sources
  # Pure functions for layering a new provider's contribution onto a prior
  # snapshot, recording per-period provenance, and returning the merged
  # result. No I/O — easy to unit test.
  #
  # Today only one provider contributes per file (single-element chain), so
  # "merge" is "new wins on conflicts, every new key is tagged with the new
  # provider's id". A future expansion will accept multiple providers in
  # priority order; the contract here is shaped to absorb that change.
  module MergePolicy
    module_function

    # @param prior [Hash] { "monthly" => {...}, "annual" => {...},
    #                       "provenance" => {"monthly"=>{...}, "annual"=>{...}} }
    # @param contribution [Hash] { monthly:, annual:, provider_id: }
    # @return [Hash] { monthly:, annual:, provenance: }
    def layer(prior, contribution)
      prior_monthly    = prior["monthly"] || {}
      prior_annual     = prior["annual"]  || {}
      prior_provenance = prior["provenance"] || { "monthly" => {}, "annual" => {} }

      {
        monthly: prior_monthly.merge(contribution[:monthly]),
        annual: prior_annual.merge(contribution[:annual]),
        provenance: {
          "monthly" => tag(prior_provenance["monthly"] || {}, contribution[:monthly], contribution[:provider_id]),
          "annual" => tag(prior_provenance["annual"] || {}, contribution[:annual], contribution[:provider_id]),
        },
      }
    end

    # @return [Hash] prior provenance with `provider_id` recorded for every
    #   period present in `new_series`. Untouched periods keep their prior tag.
    def tag(prior_provenance, new_series, provider_id)
      stamped = new_series.keys.to_h { |k| [k, provider_id] }
      prior_provenance.merge(stamped)
    end
  end
end
