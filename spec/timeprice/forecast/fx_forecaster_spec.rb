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

    it "loads the real bundled FX data and projects USD->VND forward" do
      # Temporarily override both the instance var and ENV so DataLoader resolves
      # to the real bundled data (not the spec fixtures).
      # VND is covered by _annual.json through 2024; target 2026 is within the 2y cap.
      real_root = File.expand_path("../../../data", __dir__)
      saved_env = ENV.delete("TIMEPRICE_DATA_ROOT")
      Timeprice::DataLoader.data_root = real_root

      result = described_class.project(from: "USD", to: "VND", target: "2026", window_years: 5)
      expect(result.basis_kind).to eq(:fx)
      expect(result.value).to be > 0
      expect(result.last_known_date).to match(/\A\d{4}\z/)
      expect(result.warnings).not_to include("horizon_exceeds_cap")
    ensure
      ENV["TIMEPRICE_DATA_ROOT"] = saved_env if saved_env
      Timeprice::DataLoader.data_root = nil
    end

    it "computes cross rates via USD when neither leg is USD" do
      # 2024 avg cross: (24_300/0.92 + 25_100/0.94) / 2 ≈ 26_557.59
      # 2025 avg cross: (25_800/0.95 + 26_200/0.96) / 2 ≈ 27_224.78
      # CAGR ≈ 2.51%; 1yr forward ≈ 27_908.74
      daily_a = { "2024-01-02" => { "EUR" => 0.92, "VND" => 24_300.0 },
                  "2024-06-01" => { "EUR" => 0.94, "VND" => 25_100.0 } }
      daily_b = { "2025-01-02" => { "EUR" => 0.95, "VND" => 25_800.0 },
                  "2025-06-01" => { "EUR" => 0.96, "VND" => 26_200.0 } }
      allow(Timeprice::DataLoader).to receive_messages(
        data_root: "/fake",
        load_fx_annual_fallback: nil
      )
      allow(Dir).to receive(:children).with("/fake/fx/usd")
                                      .and_return(["2024.json", "2025.json", "_annual.json"])
      allow(File).to receive(:directory?).with("/fake/fx/usd").and_return(true)
      allow(Timeprice::DataLoader).to receive(:load_fx_year).with(2024)
                                                            .and_return("base" => "USD", "rates" => daily_a)
      allow(Timeprice::DataLoader).to receive(:load_fx_year).with(2025)
                                                            .and_return("base" => "USD", "rates" => daily_b)

      result = described_class.project(from: "EUR", to: "VND", target: "2026", window_years: 1)
      expect(result.value).to be_within(200).of(27_909)
      expect(result.basis_kind).to eq(:fx)
    end
  end
end
