# frozen_string_literal: true

RSpec.describe Timeprice::Exchange do
  describe ".convert" do
    it "returns identity for same currency" do
      r = described_class.convert(amount: 100, from: "USD", to: "USD", date: "2010-06-15")
      expect(r.rate).to eq(1.0)
      expect(r.amount).to eq(100.0)
    end

    it "does direct USD-base lookup" do
      r = described_class.convert(amount: 100, from: "USD", to: "EUR", date: "2010-06-15")
      expect(r.rate).to eq(0.8150)
      expect(r.effective_date).to eq("2010-06-15")
      expect(r.amount).to be_within(1e-9).of(81.50)
    end

    it "does inverse lookup (foreign → USD)" do
      r = described_class.convert(amount: 100, from: "EUR", to: "USD", date: "2010-06-15")
      expect(r.rate).to be_within(1e-9).of(1.0 / 0.8150)
    end

    it "falls back over a weekend (Sat 2010-06-12 → Fri 2010-06-11)" do
      r = described_class.convert(amount: 100, from: "USD", to: "GBP", date: "2010-06-12")
      expect(r.effective_date).to eq("2010-06-11")
      expect(r.rate).to eq(0.6849)
    end

    it "triangulates GBP → JPY through USD on a date both rates exist" do
      r = described_class.convert(amount: 100, from: "GBP", to: "JPY", date: "2010-06-15")
      # 0.6720 USD/GBP^-1 path: rate = (USD->JPY) / (USD->GBP) = 91.50 / 0.6720
      expect(r.rate).to be_within(1e-9).of(91.50 / 0.6720)
      expect(r.effective_date).to eq("2010-06-15")
    end

    it "raises DataNotFound when triangulation legs resolve to different effective dates" do
      # On 2010-06-17 EUR & JPY exist but GBP is missing (GBP last on 06-16).
      # USD->GBP falls back to 06-16, USD->JPY resolves on 06-17 → mismatch.
      expect {
        described_class.convert(amount: 100, from: "GBP", to: "JPY", date: "2010-06-17")
      }.to raise_error(Timeprice::DataNotFound, /triangulation date mismatch/)
    end

    it "raises DataNotFound when no rate within fallback window" do
      expect {
        described_class.convert(amount: 100, from: "USD", to: "EUR", date: "2010-01-01")
      }.to raise_error(Timeprice::DataNotFound)
    end

    it "rejects malformed dates" do
      expect {
        described_class.convert(amount: 100, from: "USD", to: "EUR", date: "2010-06")
      }.to raise_error(ArgumentError, /Invalid date/)
    end
  end
end
