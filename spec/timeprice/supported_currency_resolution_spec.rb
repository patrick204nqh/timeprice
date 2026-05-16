# frozen_string_literal: true

require "timeprice"

RSpec.describe Timeprice::Supported do
  describe ".daily_currencies" do
    it "is a subset of .currencies" do
      expect(described_class.daily_currencies - described_class.currencies).to be_empty
    end

    it "includes the FX base (USD)" do
      expect(described_class.daily_currencies).to include("USD")
    end
  end

  describe ".annual_only_currencies" do
    it "is disjoint from .daily_currencies" do
      expect(described_class.annual_only_currencies & described_class.daily_currencies).to be_empty
    end

    it "includes VND" do
      expect(described_class.annual_only_currencies).to include("VND")
    end

    it "includes RUB" do
      expect(described_class.annual_only_currencies).to include("RUB")
    end
  end
end
