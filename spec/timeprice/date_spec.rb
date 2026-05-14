# frozen_string_literal: true

require "timeprice/date"

RSpec.describe Timeprice::Date do
  describe ".parse" do
    it "parses YYYY as annual" do
      d = described_class.parse("2010")
      expect(d.granularity).to eq(:annual)
      expect(d.to_s).to eq("2010")
    end

    it "parses YYYY-MM as monthly" do
      d = described_class.parse("2010-06")
      expect(d.granularity).to eq(:monthly)
      expect(d.to_s).to eq("2010-06")
    end

    it "parses YYYY-Qn (1..4) as quarterly" do
      d = described_class.parse("2010-Q2")
      expect(d.granularity).to eq(:quarterly)
      expect(d.to_s).to eq("2010-Q2")
    end

    it "parses YYYY-MM-DD as daily" do
      d = described_class.parse("2010-06-15")
      expect(d.granularity).to eq(:daily)
      expect(d.to_s).to eq("2010-06-15")
    end

    it "rejects unparseable input" do
      expect { described_class.parse("not-a-date") }.to raise_error(Timeprice::InvalidDate)
    end

    it "rejects an out-of-range quarter" do
      expect { described_class.parse("2010-Q5") }.to raise_error(Timeprice::InvalidDate)
    end
  end

  describe ".coerce" do
    it "returns Date instances unchanged" do
      d = described_class.parse("2010")
      expect(described_class.coerce(d)).to equal(d)
    end

    it "parses string inputs" do
      expect(described_class.coerce("2010-06").granularity).to eq(:monthly)
    end
  end
end
