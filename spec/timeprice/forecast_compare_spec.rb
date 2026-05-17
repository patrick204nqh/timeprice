# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Timeprice, ".compare with forecast:" do
  # This spec exercises the real bundled CPI/FX data so that the CAGR window
  # contains enough monthly observations to produce a non-zero sigma band.
  around do |example|
    real_data = File.expand_path("../../data", __dir__)
    original_env = ENV.fetch("TIMEPRICE_DATA_ROOT", nil)
    ENV["TIMEPRICE_DATA_ROOT"] = real_data
    Timeprice::DataLoader.clear_cache!
    example.run
  ensure
    ENV["TIMEPRICE_DATA_ROOT"] = original_env
    Timeprice::DataLoader.clear_cache!
  end

  it "defaults to forecast: false and raises DataNotFound on future target" do
    expect do
      described_class.compare(amount: 100, from: %w[USD 2010], to: %w[VND 2050])
    end.to raise_error(Timeprice::DataNotFound)
  end

  it "returns a forecast-tagged result when forecast: true and target is future" do
    result = described_class.compare(
      amount: 100,
      from: %w[USD 2010],
      to: %w[VND 2030],
      forecast: true
    )
    expect(result.granularity).to eq(:forecast)
    expect(result.forecast).to be_a(Hash)
    expect(result.forecast[:basis_kind]).to eq(:cpi)
    expect(result.forecast[:low]).to be < result.amount
    expect(result.forecast[:high]).to be > result.amount
    expect(result.forecast[:last_known_date]).to match(/\A\d{4}(-\d{2})?\z/)
  end

  it "is a no-op when forecast: true but target is within bundled range" do
    in_range = described_class.compare(
      amount: 100, from: %w[USD 2010], to: %w[VND 2024], forecast: true
    )
    expect(in_range.granularity).not_to eq(:forecast)
    expect(in_range.forecast).to be_nil
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
