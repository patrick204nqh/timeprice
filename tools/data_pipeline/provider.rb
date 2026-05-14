# frozen_string_literal: true

require_relative "namespace"

require_relative "_common"
require_relative "country_file"
require_relative "series"

module Tools
  module DataPipeline
    # A single CPI data provider — one upstream API client.
    #
    # A subclass implements `fetch` and returns `[monthly_hash, annual_hash]`
    # (either may be empty). File output, drift detection, and merging with
    # the prior snapshot live in CountryFile so a future multi-provider chain
    # can drive one file write from several providers.
    #
    # Subclasses declare metadata via the configure DSL (see BLS, ONS,
    # Eurostat for examples).
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
        # @!attribute [rw] provider_id
        #   @return [String] stable short id recorded as per-period provenance
        #   (e.g. "bls", "ons", "eurostat"). Lowercase, no spaces.
        attr_accessor :country_code, :country_label, :source_label,
                      :default_base_year, :log_label, :provider_id
      end

      # Convenience for subclasses to register metadata in one block.
      def self.configure(country_code:, country_label:, source_label:,
                         default_base_year:, log_label:, provider_id:)
        self.country_code = country_code
        self.country_label = country_label
        self.source_label = source_label
        self.default_base_year = default_base_year
        self.log_label = log_label
        self.provider_id = provider_id
      end

      def self.run
        new.run
      end

      # @return [Series] the (monthly, quarterly, annual) series fetched
      #   from upstream. Empty hashes for granularities the provider does
      #   not emit. Use `Series.build(monthly: ..., annual: ...)`.
      def fetch
        raise NotImplementedError, "#{self.class} must implement #fetch returning a Series"
      end

      def run
        series = fetch
        unless series.is_a?(Series)
          raise "#{self.class}#fetch must return a Tools::DataPipeline::Series " \
                "(got #{series.class})"
        end
        series.each_present do |g, h|
          Tools::DataPipeline.validate_positive_numeric!(h, "#{log_label} #{g}")
        end
        country_file.write_merged(series: series, provider_id: self.class.provider_id)
      end

      private

      def country_file
        CountryFile.new(
          country_code: self.class.country_code,
          country_label: self.class.country_label,
          source_label: self.class.source_label,
          default_base_year: self.class.default_base_year,
          log_label: self.class.log_label
        )
      end

      def log_label = self.class.log_label
    end
  end
end
