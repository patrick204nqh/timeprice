# frozen_string_literal: true

module Timeprice
  # Closed set of CPI-resolution granularities and the rules for combining /
  # rendering them. Owns the lattice so callers don't hand-maintain it.
  module Granularity
    DAILY                          = :daily
    MONTHLY                        = :monthly
    QUARTERLY                      = :quarterly
    ANNUAL                         = :annual
    ANNUAL_FROM_MONTHLY_AVG         = :annual_from_monthly_avg
    ANNUAL_FROM_QUARTERLY_AVG       = :annual_from_quarterly_avg
    ANNUAL_FROM_PARTIAL_MONTHS      = :annual_from_partial_months
    ANNUAL_FROM_PARTIAL_QUARTERS    = :annual_from_partial_quarters
    QUARTERLY_FROM_ANNUAL_FALLBACK  = :quarterly_from_annual_fallback
    QUARTERLY_FROM_MONTHLY_AVG      = :quarterly_from_monthly_avg
    MONTHLY_FROM_QUARTERLY_FALLBACK = :monthly_from_quarterly_fallback
    MONTHLY_FROM_ANNUAL_FALLBACK    = :monthly_from_annual_fallback

    # Most-degraded first — `merge` returns the first match. DAILY is the
    # highest-precision FX tag; MONTHLY is the highest-precision CPI tag.
    # Compare uses merge() across both legs, so the most-degraded tag in
    # either leg wins.
    #
    # Ordering rationale (worst → best):
    #   1. Cross-grain fallbacks where the asked resolution is finer than
    #      what's available (annual stretched to month/quarter).
    #   2. Partial-period averages — asked annual but only some months/
    #      quarters in the year are populated. Highly biased by seasonality.
    #   3. Same-or-coarser fallback (quarter stretched to month).
    #   4. Full-period derived averages (complete 4-quarter or 12-month mean
    #      standing in for the asked coarser resolution).
    #   5. Native series at the asked resolution.
    PRECEDENCE = [
      MONTHLY_FROM_ANNUAL_FALLBACK,
      ANNUAL_FROM_PARTIAL_QUARTERS,
      ANNUAL_FROM_PARTIAL_MONTHS,
      QUARTERLY_FROM_ANNUAL_FALLBACK,
      MONTHLY_FROM_QUARTERLY_FALLBACK,
      ANNUAL_FROM_QUARTERLY_AVG,
      QUARTERLY_FROM_MONTHLY_AVG,
      ANNUAL_FROM_MONTHLY_AVG,
      ANNUAL,
      QUARTERLY,
      MONTHLY,
      DAILY,
    ].freeze

    HUMAN_LABELS = {
      DAILY => "daily",
      MONTHLY => "monthly",
      QUARTERLY => "quarterly",
      ANNUAL => "annual",
      ANNUAL_FROM_MONTHLY_AVG => "annual (avg of months)",
      ANNUAL_FROM_QUARTERLY_AVG => "annual (avg of quarters)",
      ANNUAL_FROM_PARTIAL_MONTHS => "annual (partial-year, avg of available months)",
      ANNUAL_FROM_PARTIAL_QUARTERS => "annual (partial-year, avg of available quarters)",
      QUARTERLY_FROM_ANNUAL_FALLBACK => "quarter (annual fallback)",
      QUARTERLY_FROM_MONTHLY_AVG => "quarter (avg of months)",
      MONTHLY_FROM_QUARTERLY_FALLBACK => "month (quarter unavailable)",
      MONTHLY_FROM_ANNUAL_FALLBACK => "month (annual fallback)",
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
