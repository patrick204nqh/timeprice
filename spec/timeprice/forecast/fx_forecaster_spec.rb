# frozen_string_literal: true

require "timeprice/forecast/fx_forecaster"

RSpec.describe Timeprice::Forecast::FxForecaster do
  describe ".project" do
    it "projects an FX rate forward and respects the 2-year FX horizon cap" do
      # Build a synthetic annual-only FX series: USD->XYZ rising 6%/yr for 5 years.
      annual = (2020..2025).to_h { |y| [y.to_s, 10.0 * (1.06**(y - 2020))] }
      allow(described_class).to receive(:load_annual_series).with("USD", "XYZ").and_return(annual)

      result = described_class.project(from: "USD", to: "XYZ", target: "2027", window_years: 5)
      expect(result.basis_kind).to eq(:fx)
      expect(result.last_known_date).to eq("2025")
      expect(result.horizon_months).to eq(24)
      # 10 * 1.06^5 ≈ 13.382 then 2 more years at 6% ≈ 15.03
      expect(result.value).to be_within(0.05).of(15.03)
      expect(result.warnings).to eq([])
    end

    it "flags horizon_exceeds_cap past 2 years forward" do
      annual = (2020..2025).to_h { |y| [y.to_s, 10.0 * (1.04**(y - 2020))] }
      allow(described_class).to receive(:load_annual_series).with("USD", "XYZ").and_return(annual)

      result = described_class.project(from: "USD", to: "XYZ", target: "2030", window_years: 5)
      expect(result.warnings).to include("horizon_exceeds_cap")
    end
  end
end
