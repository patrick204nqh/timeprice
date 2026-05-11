# frozen_string_literal: true

RSpec.describe Timeprice::Compare do
  describe ".run" do
    it "for same currency, equals plain inflation (convention sanity check)" do
      # Compare(100, USD@2010, USD@2024) must equal Inflation(100, 2010→2024, US)
      # because USD->USD FX is identity and the destination country is US.
      compare = described_class.run(
        amount: 100, from: ["USD", "2010"], to: ["USD", "2024"]
      )
      infl = Timeprice::Inflation.adjust(
        amount: 100, from: "2010", to: "2024", country: "US"
      )
      expect(compare.amount).to be_within(1e-9).of(infl.amount)
    end

    it "regression: convert-at-source then inflate-in-destination (NOT the reverse)" do
      # 100 USD in 2010 → VND in 2025.
      # Correct path: convert at 2010 USD→VND, then inflate VND from 2010→2025.
      # Wrong path:   inflate 100 USD from 2010→2025 with US CPI, then convert at 2025.
      #
      # Fixtures:
      #   USD→VND on 2010-06-30 = 19000.0
      #   VN CPI 2010 = 100.0, 2025 = 205.0   → ratio 2.05
      # Expected correct value: 100 * 19000.0 * 2.05 = 3_895_000.0
      result = described_class.run(
        amount: 100, from: ["USD", "2010"], to: ["VND", "2025"]
      )
      expected_correct = 100 * 19000.0 * (205.0 / 100.0)
      expect(result.amount).to be_within(1e-6).of(expected_correct)

      # The "wrong" answer (inflate US first, then convert at destination FX) would be:
      # 100 * (US CPI 2025 / US CPI 2010) * (FX USD→VND at 2025) — we don't have 2025 FX
      # in the fixture, but symbolically it would NOT equal the value above, and crucially
      # the convention assertion is: we used the SOURCE-date FX rate.
      expect(result.fx_rate).to eq(19000.0)
      expect(result.cpi_ratio).to be_within(1e-9).of(205.0 / 100.0)
      expect(result.country).to eq("VN")
      expect(result.converted_amount).to be_within(1e-9).of(100 * 19000.0)
    end

    it "raises UnsupportedCurrency for unknown destination currency" do
      expect {
        described_class.run(amount: 100, from: ["USD", "2010"], to: ["ZZZ", "2024"])
      }.to raise_error(Timeprice::UnsupportedCurrency, /ZZZ/)
    end
  end
end
