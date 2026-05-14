# frozen_string_literal: true

require_relative "namespace"

module Tools
  module DataPipeline
    # Converts CPI provenance between two representations:
    #
    #   - Internal (per-period hash), used by MergePolicy for easy point updates:
    #
    #       { "monthly"   => { "2025-01" => "imf", ... },
    #         "quarterly" => { "2025-Q1" => "abs", ... },
    #         "annual"    => { "2024"    => "imf", ... } }
    #
    #   - On-disk (range list), schema_version 4, compact and human-readable:
    #
    #       [ { "series" => "monthly", "from" => "2025-01", "to" => "2025-02",
    #           "provider" => "imf" },
    #         { "series" => "quarterly", "from" => "2024-Q1", "to" => "2024-Q4",
    #           "provider" => "abs" },
    #         { "series" => "annual",  "from" => "2024",    "to" => "2024",
    #           "provider" => "imf" } ]
    #
    # CountryFile expands on read and compacts on write — MergePolicy never sees
    # the range representation, so its single-point overwrite semantics stay
    # trivial.
    module Provenance
      SERIES = %w[monthly quarterly annual].freeze

      module_function

      # @param ranges [Array<Hash>] on-disk range list (may be nil/empty).
      # @return [Hash] internal per-period hash keyed by series.
      def expand(ranges)
        out = SERIES.to_h { |s| [s, {}] }
        Array(ranges).each do |range|
          series   = range["series"]
          provider = range["provider"]
          next unless out.key?(series)

          periods_between(series, range["from"], range["to"]).each do |period|
            out[series][period] = provider
          end
        end
        out
      end

      # @param per_period [Hash] internal per-period hash.
      # @return [Array<Hash>] sorted range list with adjacent same-provider
      #   periods collapsed.
      def compact(per_period)
        SERIES.flat_map do |series|
          runs(per_period[series] || {}, series).map do |from, to, provider|
            { "series" => series, "from" => from, "to" => to, "provider" => provider }
          end
        end
      end

      # Iterate inclusive period range. Recognises "YYYY" (annual),
      # "YYYY-MM" (monthly), and "YYYY-Qn" (quarterly).
      def periods_between(series, from, to)
        case series
        when "annual"    then (Integer(from)..Integer(to)).map(&:to_s)
        when "monthly"   then enumerate_months(from, to)
        when "quarterly" then enumerate_quarters(from, to)
        else []
        end
      end

      def enumerate_months(from, to)
        y1, m1 = from.split("-").map(&:to_i)
        y2, m2 = to.split("-").map(&:to_i)
        out = []
        y = y1
        m = m1
        until y > y2 || (y == y2 && m > m2)
          out << format("%04d-%02d", y, m)
          m += 1
          if m > 12
            m = 1
            y += 1
          end
        end
        out
      end

      def enumerate_quarters(from, to)
        y1, q1 = parse_quarter(from)
        y2, q2 = parse_quarter(to)
        out = []
        y = y1
        q = q1
        until y > y2 || (y == y2 && q > q2)
          out << format("%04d-Q%d", y, q)
          q += 1
          if q > 4
            q = 1
            y += 1
          end
        end
        out
      end

      def parse_quarter(s)
        m = s.match(/\A(\d{4})-Q([1-4])\z/)
        fail "bad quarter period: #{s.inspect}" unless m

        [m[1].to_i, m[2].to_i]
      end

      # Collapse a per-period hash into [[from, to, provider], ...] runs of
      # contiguous periods sharing the same provider. Sorted lexicographically,
      # which is also chronological for "YYYY", "YYYY-MM", and "YYYY-Qn".
      def runs(hash, series)
        return [] if hash.empty?

        sorted = hash.sort_by { |k, _| k }
        runs = []
        cur_from = cur_to = cur_provider = nil
        sorted.each do |period, provider|
          if cur_provider == provider && period == next_period(series, cur_to)
            cur_to = period
          else
            runs << [cur_from, cur_to, cur_provider] if cur_provider
            cur_from = cur_to = period
            cur_provider = provider
          end
        end
        runs << [cur_from, cur_to, cur_provider]
        runs
      end

      def next_period(series, period)
        case series
        when "annual"
          (Integer(period) + 1).to_s
        when "monthly"
          y, m = period.split("-").map(&:to_i)
          m += 1
          if m > 12
            m = 1
            y += 1
          end
          format("%04d-%02d", y, m)
        when "quarterly"
          y, q = parse_quarter(period)
          q += 1
          if q > 4
            q = 1
            y += 1
          end
          format("%04d-Q%d", y, q)
        end
      end
    end
  end
end
