# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../../lib", __dir__))
require "timeprice/schema"
require_relative "../../../tools/data_pipeline/series"

RSpec.describe Tools::DataPipeline::Series do
  describe ".build" do
    it "defaults missing granularities to empty hashes" do
      series = described_class.build(monthly: { "2024-01" => 100.0 })
      expect(series.monthly).to eq("2024-01" => 100.0)
      expect(series.quarterly).to eq({})
      expect(series.annual).to eq({})
    end
  end

  describe "#empty?" do
    it "is true when every series is empty" do
      expect(described_class.build).to be_empty
    end

    it "is false as soon as any series has data" do
      expect(described_class.build(annual: { "2020" => 100.0 })).not_to be_empty
    end
  end

  describe "#each_present" do
    it "yields only granularities that have data, in canonical order" do
      series = described_class.build(
        monthly: { "2024-01" => 100.0 },
        annual: { "2024" => 99.5 }
      )
      yielded = []
      series.each_present { |g, h| yielded << [g, h.keys] }
      expect(yielded).to eq([
                              [:monthly, ["2024-01"]],
                              [:annual, ["2024"]],
                            ])
    end
  end

  it "is immutable" do
    series = described_class.build(annual: { "2020" => 100.0 })
    expect(series.annual).to be_frozen
  end
end
