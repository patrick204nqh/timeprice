# frozen_string_literal: true

require "timeprice/schema"

RSpec.describe Timeprice::Schema do
  it "exposes the current schema version" do
    expect(described_class::CURRENT_VERSION).to eq(4)
  end

  it "accepts v3 and v4 as supported on read" do
    expect(described_class.supported?(3)).to be true
    expect(described_class.supported?(4)).to be true
    expect(described_class.supported?(5)).to be false
  end

  it "dumps a CPI file with stable key order" do
    payload = described_class.dump_cpi(
      country: "US",
      base_year: "1982-1984=100",
      monthly: { "2010-01" => 100.0 },
      annual: { "2010" => 100.0 },
      providers: [{ "id" => "bls", "label" => "BLS", "fetched_at" => "2026-05-14", "status" => "ok" }],
      provenance: { "2010-01" => "bls", "2010" => "bls" }
    )
    expect(payload["schema_version"]).to eq(4)
    expect(payload["series"].keys).to eq(%w[annual monthly])
  end

  it "includes a quarterly block in dump_cpi when present" do
    payload = described_class.dump_cpi(
      country: "AU",
      base_year: "2010=100",
      monthly: {},
      quarterly: { "2010-Q1" => 100.0 },
      annual: { "2010" => 100.0 },
      providers: [],
      provenance: {}
    )
    expect(payload["series"].keys).to include("quarterly")
  end

  describe ".assert_supported!" do
    it "is a no-op for a supported version" do
      expect { described_class.assert_supported!(4, "/tmp/x.json") }.not_to raise_error
    end

    it "raises UnsupportedSchemaVersion for an unsupported version" do
      expect { described_class.assert_supported!(99, "/tmp/x.json") }
        .to raise_error(Timeprice::UnsupportedSchemaVersion)
    end
  end

  describe "base_year round-trip" do
    it "serialises a plain base_year string" do
      expect(described_class.serialise_base_year("2010=100"))
        .to eq("base_period" => "2010", "rebased_at" => nil)
    end

    it "serialises a rebased base_year string" do
      expect(described_class.serialise_base_year("2010=100 (rebased 2026-05-11)"))
        .to eq("base_period" => "2010", "rebased_at" => "2026-05-11")
    end

    it "deserialises into a plain base_year string" do
      expect(described_class.deserialise_base_year("base_period" => "2010", "rebased_at" => nil))
        .to eq("2010=100")
    end

    it "deserialises a rebased base_year" do
      expect(described_class.deserialise_base_year(
               "base_period" => "2010", "rebased_at" => "2026-05-11"
             )).to eq("2010=100 (rebased 2026-05-11)")
    end
  end
end
