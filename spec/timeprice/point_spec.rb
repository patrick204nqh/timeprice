# frozen_string_literal: true

RSpec.describe Timeprice::Point do
  describe ".coerce" do
    it "returns a Point unchanged" do
      p = described_class.new(currency: "USD", date: "2010")
      expect(described_class.coerce(p)).to be(p)
    end

    it "accepts a [currency, date] tuple" do
      p = described_class.coerce(%w[USD 2010])
      expect(p.currency).to eq("USD")
      expect(p.date).to eq("2010")
    end

    it "accepts a [date, currency] tuple regardless of order" do
      p = described_class.coerce(%w[2010 USD])
      expect(p.currency).to eq("USD")
      expect(p.date).to eq("2010")
    end

    it "upcases the currency" do
      expect(described_class.coerce(%w[usd 2010]).currency).to eq("USD")
    end

    it "accepts YYYY-MM and YYYY-MM-DD dates" do
      expect(described_class.coerce(%w[USD 2010-06]).date).to eq("2010-06")
      expect(described_class.coerce(%w[USD 2010-06-15]).date).to eq("2010-06-15")
    end

    it "raises on malformed input" do
      expect { described_class.coerce("USD 2010") }.to raise_error(ArgumentError)
      expect { described_class.coerce(%w[USD ABC]) }.to raise_error(ArgumentError, /detect/)
      expect { described_class.coerce([1, 2, 3]) }.to raise_error(ArgumentError)
    end
  end

  describe "Compare integration" do
    it "accepts Point instances" do
      from = described_class.new(currency: "USD", date: "2010")
      to   = described_class.new(currency: "USD", date: "2024")
      result = Timeprice.compare(amount: 100, from: from, to: to)
      expect(result.from_currency).to eq("USD")
      expect(result.to_currency).to eq("USD")
    end
  end
end
