# frozen_string_literal: true

require_relative "_common"
require_relative "country_file"

module Sources
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
      country_file.write_merged(monthly: monthly, annual: annual)
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
