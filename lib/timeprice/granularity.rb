# frozen_string_literal: true

module Timeprice
  # Closed set of CPI-resolution granularities and the rules for combining /
  # rendering them. Owns the lattice so callers don't hand-maintain it.
  module Granularity
    DAILY                        = :daily
    MONTHLY                      = :monthly
    ANNUAL                       = :annual
    ANNUAL_FROM_MONTHLY_AVG      = :annual_from_monthly_avg
    MONTHLY_FROM_ANNUAL_FALLBACK = :monthly_from_annual_fallback

    # Most-degraded first — `merge` returns the first match.
    # DAILY is the highest-precision FX tag; MONTHLY is the highest-precision
    # CPI tag. Compare uses merge() across both legs, so the most-degraded
    # tag in either leg wins.
    PRECEDENCE = [
      MONTHLY_FROM_ANNUAL_FALLBACK,
      ANNUAL_FROM_MONTHLY_AVG,
      ANNUAL,
      MONTHLY,
      DAILY,
    ].freeze

    HUMAN_LABELS = {
      DAILY => "daily",
      MONTHLY => "monthly",
      ANNUAL => "annual",
      ANNUAL_FROM_MONTHLY_AVG => "annual (avg of months)",
      MONTHLY_FROM_ANNUAL_FALLBACK => "annual (month unavailable)",
    }.freeze

    module_function

    # Worst-precision-wins merge across two or more endpoint granularities.
    def merge(*tags)
      PRECEDENCE.find { |t| tags.include?(t) } || MONTHLY
    end

    # Human-readable label for CLI output. Falls through to the symbol's
    # string form so an unknown tag still renders something.
    def humanize(tag)
      HUMAN_LABELS.fetch(tag, tag.to_s)
    end
  end
end
