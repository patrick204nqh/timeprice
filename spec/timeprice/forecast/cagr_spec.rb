# frozen_string_literal: true

require "timeprice/forecast/cagr"

RSpec.describe Timeprice::Forecast::Cagr do
  describe ".compute" do
    it "returns CAGR equal to constant YoY when the series grows at a constant rate" do
      # 5% annual growth for 10 years (monthly compounding-equivalent points)
      series = {}
      base = 100.0
      120.downto(0) do |months_back|
        date = (Date.new(2025, 1, 1) << months_back).strftime("%Y-%m")
        series[date] = base * (1.05**((120 - months_back) / 12.0))
      end

      result = described_class.compute(series: series, last_date: "2025-01", window_years: 10)

      expect(result[:cagr]).to be_within(1e-6).of(0.05)
      expect(result[:sigma_yoy]).to be_within(1e-6).of(0.0)
      expect(result[:window_start]).to eq("2015-01")
      expect(result[:window_end]).to eq("2025-01")
      expect(result[:samples]).to be >= 10
    end

    it "computes non-zero sigma when YoY returns vary" do
      series = {
        "2020-01" => 100.0, "2021-01" => 102.0, "2022-01" => 108.0,
        "2023-01" => 110.0, "2024-01" => 117.0, "2025-01" => 120.0
      }
      result = described_class.compute(series: series, last_date: "2025-01", window_years: 5)
      expect(result[:cagr]).to be_within(1e-3).of(((120.0 / 100.0)**(1.0 / 5)) - 1.0)
      expect(result[:sigma_yoy]).to be > 0.01
      expect(result[:samples]).to eq(6)
    end

    it "raises when window has fewer than 2 samples" do
      expect do
        described_class.compute(series: { "2025-01" => 100.0 }, last_date: "2025-01", window_years: 10)
      end.to raise_error(ArgumentError, /at least 2 points/)
    end

    it "accepts annual-only series" do
      series = (2015..2025).to_h { |y| [y.to_s, 100.0 * (1.04**(y - 2015))] }
      result = described_class.compute(series: series, last_date: "2025", window_years: 10)
      expect(result[:cagr]).to be_within(1e-6).of(0.04)
      expect(result[:window_start]).to eq("2015")
      expect(result[:window_end]).to eq("2025")
    end
  end
end
