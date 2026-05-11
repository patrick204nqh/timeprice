# frozen_string_literal: true

# Sanity coverage for the v0.5 expansion (AU, CA, KR, CN, RU). Locks in:
#   * quarterly key parsing (AU)
#   * quarterly→annual fallback for "YYYY-Qn" queries against annual-only data
#   * monthly→annual fallback for the WB-baseline-only countries (CN, RU)
#   * Supported.country?/currency? gains the new entries via the manifest
RSpec.describe "v0.5 country expansion" do
  describe "AU (quarterly)" do
    it "returns :quarterly granularity for YYYY-Qn keys" do
      result = Timeprice::Inflation.adjust(
        amount: 100, from: "2010-Q1", to: "2024-Q4", country: "AU"
      )
      expect(result.granularity).to eq(:quarterly)
      expect(result.from_index).to eq(95.2)
      expect(result.to_index).to eq(138.3)
    end

    it "derives annual from the four quarterly observations" do
      result = Timeprice::Inflation.adjust(
        amount: 100, from: "2010", to: "2024", country: "AU"
      )
      # AU annual is present, so it wins over derived. Confirm it's :annual.
      expect(result.granularity).to eq(:annual)
    end

    it "falls back from monthly query to the quarter that contains it" do
      # AU has no monthly series. 2010-02 should resolve via 2010-Q1.
      result = Timeprice::Inflation.adjust(
        amount: 100, from: "2010-02", to: "2024-08", country: "AU"
      )
      expect(result.granularity).to eq(:monthly_from_quarterly_fallback)
      expect(result.from_index).to eq(95.2) # 2010-Q1
      expect(result.to_index).to eq(137.7)  # 2024-Q3 (covers Aug)
    end
  end

  describe "CA (monthly + annual)" do
    it "computes monthly inflation" do
      result = Timeprice::Inflation.adjust(
        amount: 100, from: "2010-01", to: "2024-12", country: "CA"
      )
      expect(result.granularity).to eq(:monthly)
    end
  end

  describe "KR (monthly + annual)" do
    it "computes annual inflation" do
      r = Timeprice::Inflation.rate(from: "2010", to: "2024", country: "KR")
      expect(r).to be_within(1e-6).of((114.2 / 84.0) - 1.0)
    end
  end

  describe "CN/RU (annual-only)" do
    it "tags CN monthly queries as falling back to annual" do
      result = Timeprice::Inflation.adjust(
        amount: 100, from: "2010-06", to: "2024-03", country: "CN"
      )
      expect(result.granularity).to eq(:monthly_from_annual_fallback)
    end

    it "raises DataNotFound for RU dates outside the bundled range" do
      expect do
        Timeprice::Inflation.adjust(amount: 100, from: "1990", to: "2024", country: "RU")
      end.to raise_error(Timeprice::DataNotFound)
    end
  end

  describe "Supported metadata" do
    it "lists all new countries" do
      %w[AU CA KR CN RU].each do |c|
        expect(Timeprice::Supported.country?(c)).to be(true), "expected #{c} to be supported"
      end
    end

    it "lists all new currencies" do
      %w[AUD CAD KRW CNY RUB].each do |c|
        expect(Timeprice::Supported.currency?(c)).to be(true), "expected #{c} to be supported"
      end
    end

    it "maps countries to their primary currency" do
      {
        "AU" => "AUD", "CA" => "CAD", "KR" => "KRW", "CN" => "CNY", "RU" => "RUB"
      }.each do |country, currency|
        expect(Timeprice::Supported.currency_for_country(country)).to eq(currency)
      end
    end

    it "marks KRW and VND as zero-decimal" do
      # KRW has no minor unit in everyday use even though ISO 4217 nominally
      # records 0 decimals — the gem should render whole-number amounts.
      expect(Timeprice::Supported.decimals_for("KRW")).to eq(0)
      expect(Timeprice::Supported.decimals_for("VND")).to eq(0)
      expect(Timeprice::Supported.decimals_for("AUD")).to eq(2)
    end
  end
end
