# frozen_string_literal: true

require_relative "../../../scripts/sources/merge_policy"

RSpec.describe Sources::MergePolicy do
  describe ".layer" do
    let(:contribution) do
      { monthly: { "2026-01" => 325.0 }, annual: { "2025" => 322.5 }, provider_id: "bls" }
    end

    context "with no prior snapshot" do
      it "writes the contribution and tags every new period with the provider id" do
        result = described_class.layer({}, contribution)

        expect(result[:monthly]).to eq("2026-01" => 325.0)
        expect(result[:annual]).to eq("2025" => 322.5)
        expect(result[:provenance]).to eq(
          "monthly" => { "2026-01" => "bls" },
          "quarterly" => {},
          "annual" => { "2025" => "bls" }
        )
      end
    end

    context "with a prior snapshot from a different provider" do
      let(:prior) do
        {
          "monthly" => { "2025-12" => 324.0 },
          "annual" => { "2024" => 314.4 },
          "provenance" => {
            "monthly" => { "2025-12" => "world_bank" },
            "annual" => { "2024" => "world_bank" },
          },
        }
      end

      it "keeps prior periods with their original provenance" do
        result = described_class.layer(prior, contribution)

        expect(result[:monthly]).to eq("2025-12" => 324.0, "2026-01" => 325.0)
        expect(result[:provenance]["monthly"]).to eq(
          "2025-12" => "world_bank",
          "2026-01" => "bls"
        )
      end

      it "overwrites both value and provenance when a new provider has the same period" do
        overlap = { monthly: { "2025-12" => 324.5 }, annual: {}, provider_id: "imf" }
        result = described_class.layer(prior, overlap)

        expect(result[:monthly]["2025-12"]).to eq(324.5)
        expect(result[:provenance]["monthly"]["2025-12"]).to eq("imf")
      end
    end
  end
end
