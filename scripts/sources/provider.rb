# frozen_string_literal: true

require_relative "_common"

module Sources
  # A single CPI data provider — one upstream API client.
  #
  # A subclass implements `fetch` and returns `[monthly_hash, annual_hash]`
  # (either may be empty). The provider also handles, today, file output —
  # validation, drift detection vs the prior snapshot, rebase renormalization
  # when drift exceeds 0.5%, merging into the existing JSON file, writing the
  # canonical `data/cpi/<code>.json` shape, and the one-line summary log.
  #
  # Subclasses declare metadata via the DSL class methods (see the BLS, ONS,
  # Eurostat, and WorldBank sources for examples).
  #
  # NOTE: This class will lose its file-output responsibilities in a later
  # refactor that introduces CountryFile to orchestrate multi-provider chains.
  # For now, single-provider behavior is unchanged.
  class Provider
    class << self
      # @!attribute [rw] country_code
      #   @return [String] lowercase two-letter code used in the data filename
      # @!attribute [rw] country_label
      #   @return [String] human label used in the summary log line
      # @!attribute [rw] source_label
      #   @return [String] stored under "source" in the JSON
      # @!attribute [rw] default_base_year
      #   @return [String] base_year written if the file doesn't exist yet
      # @!attribute [rw] log_label
      #   @return [String] short prefix for log lines (e.g. "BLS")
      attr_accessor :country_code, :country_label, :source_label,
                    :default_base_year, :log_label
    end

    # Convenience for subclasses to register metadata in one block.
    def self.configure(country_code:, country_label:, source_label:,
                       default_base_year:, log_label:)
      self.country_code = country_code
      self.country_label = country_label
      self.source_label = source_label
      self.default_base_year = default_base_year
      self.log_label = log_label
    end

    def self.run
      new.run
    end

    # @return [Array(Hash, Hash)] [monthly, annual] series fetched from upstream
    def fetch
      raise NotImplementedError, "#{self.class} must implement #fetch returning [monthly, annual]"
    end

    def run
      monthly, annual = fetch
      monthly ||= {}
      annual  ||= {}

      Sources.validate_positive_numeric!(monthly, "#{log_label} monthly") unless monthly.empty?
      Sources.validate_positive_numeric!(annual,  "#{log_label} annual")  unless annual.empty?

      path = File.join(Sources::DATA_ROOT, "cpi", "#{country_code}.json")
      prior = Sources.read_json_if_exists(path)
      prior_monthly = (prior && prior["monthly"]) || {}
      prior_annual  = (prior && prior["annual"])  || {}
      base_year = (prior && prior["base_year"]) || default_base_year

      # Drift is most informative on whichever granularity has the most overlap.
      # Prefer monthly when the new series carries any; else annual.
      drift_prior, drift_new = monthly.any? ? [prior_monthly, monthly] : [prior_annual, annual]
      verdict, ratio, msg = Sources.cpi_drift_check(drift_prior, drift_new)
      Sources.log "#{log_label} drift: #{msg}"
      if verdict == :rebase
        Sources.log "#{log_label}: rebase — renormalizing prior by ratio #{ratio}"
        prior_monthly = Sources.renormalize(prior_monthly, ratio)
        prior_annual  = Sources.renormalize(prior_annual,  ratio)
        base_year = "rebased #{Sources.today}"
      end

      merged_monthly = prior_monthly.merge(monthly)
      merged_annual  = prior_annual.merge(annual)
      new_points = (monthly.keys - prior_monthly.keys).size + (annual.keys - prior_annual.keys).size
      range_source = merged_monthly.any? ? merged_monthly : merged_annual
      range = range_source.keys.minmax

      data = {
        "schema_version" => 1,
        "country" => country_code.upcase,
        "base_year" => base_year,
        "source" => source_label,
        "updated_at" => Sources.today,
        "monthly" => merged_monthly,
        "annual" => merged_annual,
      }
      Sources.write_json(path, data)
      Sources.log "#{log_label}(#{country_label}): #{merged_monthly.size} monthly + " \
                  "#{merged_annual.size} annual data points, range #{range.first}..#{range.last}, " \
                  "#{new_points} new since last run."
    end

    private

    def country_code      = self.class.country_code
    def country_label     = self.class.country_label
    def source_label      = self.class.source_label
    def default_base_year = self.class.default_base_year
    def log_label         = self.class.log_label
  end
end
