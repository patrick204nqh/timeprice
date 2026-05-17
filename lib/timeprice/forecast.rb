# frozen_string_literal: true

module Timeprice
  # Forward-projection of CPI / FX series past the last bundled data point.
  #
  # Method: trailing-window CAGR for the point estimate, ±1σ of trailing
  # year-over-year changes for the band. Pure-Ruby, deterministic, no
  # network calls or stats dependencies.
  #
  # All results are explicitly tagged so callers never confuse them with
  # measured data. The {Forecast::Result#warnings} array surfaces horizon-cap
  # violations and insufficient-window conditions.
  module Forecast
    Result = Data.define(
      :value, :low, :high,
      :projection_method, :window_years, :sigma_pct,
      :last_known_date, :target_date, :horizon_months,
      :basis_kind, :warnings
    )
  end
end
