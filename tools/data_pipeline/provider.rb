# frozen_string_literal: true

require_relative "namespace"

require_relative "_common"
require_relative "country_file"
require_relative "series"

module Tools
  module DataPipeline
    # A single CPI data provider — one upstream API client.
    #
    # A subclass implements `fetch` and returns a {Series}. File output,
    # drift detection, and merging with the prior snapshot live in
    # CountryFile so a future multi-provider chain can drive one file
    # write from several providers.
    #
    # Subclasses declare metadata via the {Provider.configure} DSL and are
    # automatically pushed into {Provider.registry}. The Runner iterates
    # the registry in `priority` order; lower numbers run first.
    class Provider
      class << self
        attr_accessor :country_code, :country_label, :source_label,
                      :default_base_year, :log_label, :provider_id,
                      :priority, :critical, :source_file
      end

      # Every Provider subclass that calls {.configure} registers here by
      # default. Pass `register: false` to opt out (for fallback-only
      # providers that are dispatched by another module).
      REGISTRY = [] # rubocop:disable Style/MutableConstant

      def self.registry
        REGISTRY
      end

      def self.configure(country_code:, country_label:, source_label:,
                         default_base_year:, log_label:, provider_id:,
                         priority: 100, critical: false, register: true)
        self.country_code = country_code
        self.country_label = country_label
        self.source_label = source_label
        self.default_base_year = default_base_year
        self.log_label = log_label
        self.provider_id = provider_id
        self.priority = priority
        self.critical = critical
        self.source_file = caller_locations(1, 1).first.path
        REGISTRY << self if register && !REGISTRY.include?(self)
      end

      def self.critical?
        critical == true
      end

      def self.run
        new.run
      end

      # @return [Series] the (monthly, quarterly, annual) series fetched
      #   from upstream. Use `Series.build(monthly: ..., annual: ...)`.
      def fetch
        fail NotImplementedError, "#{self.class} must implement #fetch returning a Series"
      end

      def run
        series = fetch
        unless series.is_a?(Series)
          fail "#{self.class}#fetch must return a Tools::DataPipeline::Series " \
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
