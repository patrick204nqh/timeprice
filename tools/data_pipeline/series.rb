# frozen_string_literal: true

require_relative "namespace"

module Tools
  module DataPipeline
    # Frozen value object holding the three CPI series a provider can return:
    # monthly, quarterly, annual. Replaces the previous `[monthly, annual]` /
    # `[monthly, quarterly, annual]` positional return — no more dispatching
    # on `result.length`.
    Series = Data.define(:monthly, :quarterly, :annual) do
      def self.build(monthly: {}, quarterly: {}, annual: {})
        new(monthly: monthly.freeze, quarterly: quarterly.freeze, annual: annual.freeze)
      end

      def empty?
        monthly.empty? && quarterly.empty? && annual.empty?
      end

      # Yields [granularity_symbol, hash] for each non-empty series, in the
      # canonical order monthly, quarterly, annual.
      def each_present
        Timeprice::Schema::GRANULARITIES.each do |g|
          h = public_send(g)
          yield g, h unless h.empty?
        end
      end
    end
  end
end
