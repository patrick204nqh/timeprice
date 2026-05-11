# frozen_string_literal: true

module Sources
  # Converts CPI provenance between two representations:
  #
  #   - Internal (per-period hash), used by MergePolicy for easy point updates:
  #
  #       { "monthly" => { "2025-01" => "imf", "2025-02" => "imf", ... },
  #         "annual"  => { "2024" => "imf", ... } }
  #
  #   - On-disk (range list), schema_version 2, compact and human-readable:
  #
  #       [ { "series" => "monthly", "from" => "2025-01", "to" => "2025-02",
  #           "provider" => "imf" },
  #         { "series" => "annual",  "from" => "2024",    "to" => "2024",
  #           "provider" => "imf" } ]
  #
  # CountryFile expands on read and compacts on write — MergePolicy never sees
  # the range representation, so its single-point overwrite semantics stay
  # trivial.
  module Provenance
    module_function

    # @param ranges [Array<Hash>] on-disk range list (may be nil/empty).
    # @return [Hash] internal per-period hash with "monthly" and "annual" keys.
    def expand(ranges)
      out = { "monthly" => {}, "annual" => {} }
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
      %w[monthly annual].flat_map do |series|
        runs(per_period[series] || {}, series).map do |from, to, provider|
          { "series" => series, "from" => from, "to" => to, "provider" => provider }
        end
      end
    end

    # Iterate inclusive period range. Recognises "YYYY" (annual) and
    # "YYYY-MM" (monthly) shapes.
    def periods_between(series, from, to)
      case series
      when "annual"  then (Integer(from)..Integer(to)).map(&:to_s)
      when "monthly" then enumerate_months(from, to)
      else []
      end
    end

    def enumerate_months(from, to)
      y1, m1 = from.split("-").map(&:to_i)
      y2, m2 = to.split("-").map(&:to_i)
      out = []
      y, m = y1, m1
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

    # Collapse a per-period hash into [[from, to, provider], ...] runs of
    # contiguous periods sharing the same provider. Sorted lexicographically,
    # which is also chronological for "YYYY" and "YYYY-MM".
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
      when "annual"  then (Integer(period) + 1).to_s
      when "monthly"
        y, m = period.split("-").map(&:to_i)
        m += 1
        if m > 12
          m = 1
          y += 1
        end
        format("%04d-%02d", y, m)
      end
    end
  end
end
