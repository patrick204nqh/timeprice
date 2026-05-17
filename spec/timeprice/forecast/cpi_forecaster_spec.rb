# frozen_string_literal: true

require "timeprice/forecast/cpi_forecaster"

RSpec.describe Timeprice::Forecast::CpiForecaster do
  describe ".project" do
    # Slight noise on top of a 4% trend so sigma_yoy > 0 and low < value < high.
    let(:noise) { [0, 0.5, -0.3, 0.4, -0.2, 0.6, -0.4, 0.3, -0.1, 0.5, -0.3, 0.2] }
    let(:noisy_4pct_monthly) do
      (0..120).each_with_object({}) do |months, h|
        d = (Date.new(2015, 1, 1) >> months).strftime("%Y-%m")
        h[d] = (100.0 * (1.04**(months / 12.0))) + noise[months % noise.size]
      end
    end

    it "projects CPI forward using trailing CAGR with a sigma band" do
      synthetic = {
        "schema_version" => 3,
        "country" => "ZZ",
        "series" => { "monthly" => noisy_4pct_monthly, "annual" => {} },
      }
      allow(Timeprice::DataLoader).to receive(:load_cpi).with("ZZ").and_return(synthetic)

      result = described_class.project(country: "ZZ", target: "2030-01", window_years: 10)

      expect(result.last_known_date).to eq("2025-01")
      expect(result.horizon_months).to eq(60)
      # last value ≈ 100 * 1.04^10 = 148.024. 5y forward at ~4%: close to 180.09
      expect(result.value).to be_within(2.0).of(180.09)
      expect(result.low).to be < result.value
      expect(result.high).to be > result.value
      expect(result.projection_method).to eq("cagr_trailing")
      expect(result.window_years).to eq(10)
      expect(result.warnings).to eq([])
    end

    it "flags horizon_exceeds_cap past 5 years forward" do
      synthetic = {
        "schema_version" => 3,
        "country" => "ZZ",
        "series" => {
          "monthly" => (0..120).each_with_object({}) do |m, h|
            d = (Date.new(2015, 1, 1) >> m).strftime("%Y-%m")
            h[d] = 100.0 * (1.03**(m / 12.0))
          end,
          "annual" => {},
        },
      }
      allow(Timeprice::DataLoader).to receive(:load_cpi).with("ZZ").and_return(synthetic)

      result = described_class.project(country: "ZZ", target: "2035-01", window_years: 10)
      expect(result.warnings).to include("horizon_exceeds_cap")
    end

    it "falls back to annual series when monthly is empty" do
      synthetic = {
        "schema_version" => 3,
        "country" => "ZZ",
        "series" => {
          "monthly" => {},
          "annual" => (2010..2025).to_h { |y| [y.to_s, 100.0 * (1.04**(y - 2010))] },
        },
      }
      allow(Timeprice::DataLoader).to receive(:load_cpi).with("ZZ").and_return(synthetic)

      result = described_class.project(country: "ZZ", target: "2028", window_years: 10)
      expect(result.last_known_date).to eq("2025")
      expect(result.horizon_months).to eq(36)
      expect(result.value).to be > 100.0 * (1.04**15) # higher than last measured
    end
  end
end
