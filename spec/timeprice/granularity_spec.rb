# frozen_string_literal: true

require "timeprice/granularity"

RSpec.describe Timeprice::Granularity do
  let(:monthly)  { described_class::MONTHLY }
  let(:annual)   { described_class::ANNUAL }
  let(:avg)      { described_class::ANNUAL_FROM_MONTHLY_AVG }
  let(:fallback) { described_class::MONTHLY_FROM_ANNUAL_FALLBACK }

  describe ".merge" do
    it "returns :monthly when both ends are clean" do
      expect(described_class.merge(monthly, monthly)).to eq(monthly)
    end

    it "prefers :annual over :monthly" do
      expect(described_class.merge(annual, monthly)).to eq(annual)
    end

    it "prefers :annual_from_monthly_avg over :annual" do
      expect(described_class.merge(avg, annual)).to eq(avg)
    end

    it "prefers :monthly_from_annual_fallback over everything else" do
      expect(described_class.merge(fallback, avg)).to eq(fallback)
    end

    it "falls back to :monthly when given no tags" do
      expect(described_class.merge).to eq(monthly)
    end
  end

  describe ".humanize" do
    it "renders human-friendly labels for known tags" do
      expect(described_class.humanize(fallback)).to eq("month (annual fallback)")
      expect(described_class.humanize(avg)).to eq("annual (avg of months)")
    end

    it "stringifies unknown tags rather than raising" do
      expect(described_class.humanize(:novel)).to eq("novel")
    end
  end
end
