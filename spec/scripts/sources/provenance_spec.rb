# frozen_string_literal: true

require_relative "../../../scripts/sources/provenance"

RSpec.describe Sources::Provenance do
  describe ".compact" do
    it "collapses contiguous same-provider periods into a single range" do
      per_period = {
        "monthly" => { "2025-01" => "bls", "2025-02" => "bls", "2025-03" => "bls" },
        "annual" => {},
      }
      expect(described_class.compact(per_period)).to eq([
                                                          { "series" => "monthly", "from" => "2025-01",
                                                            "to" => "2025-03", "provider" => "bls" },
                                                        ])
    end

    it "splits at provider transitions" do
      per_period = {
        "monthly" => {},
        "annual" => { "2000" => "world_bank", "2001" => "world_bank", "2002" => "imf", "2003" => "imf" },
      }
      expect(described_class.compact(per_period)).to eq([
                                                          { "series" => "annual", "from" => "2000",
                                                            "to" => "2001", "provider" => "world_bank" },
                                                          { "series" => "annual", "from" => "2002",
                                                            "to" => "2003", "provider" => "imf" },
                                                        ])
    end

    it "splits at period gaps (non-contiguous months)" do
      per_period = {
        "monthly" => { "2025-09" => "bls", "2025-11" => "bls" },
        "annual" => {},
      }
      expect(described_class.compact(per_period).map { |r| [r["from"], r["to"]] }).to eq(
        [%w[2025-09 2025-09], %w[2025-11 2025-11]]
      )
    end

    it "returns an empty list for empty input" do
      expect(described_class.compact("monthly" => {}, "annual" => {})).to eq([])
    end
  end

  describe ".expand" do
    it "round-trips through compact" do
      original = {
        "monthly" => { "2025-01" => "bls", "2025-02" => "bls", "2025-03" => "imf" },
        "annual" => { "2024" => "bls" },
      }
      expect(described_class.expand(described_class.compact(original))).to eq(original)
    end

    it "handles nil input as empty" do
      expect(described_class.expand(nil)).to eq("monthly" => {}, "annual" => {})
    end

    it "ignores unknown series" do
      ranges = [{ "series" => "quarterly", "from" => "2025-Q1", "to" => "2025-Q2", "provider" => "x" }]
      expect(described_class.expand(ranges)).to eq("monthly" => {}, "annual" => {})
    end
  end
end
