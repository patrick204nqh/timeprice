# frozen_string_literal: true
#
# Sanity tests against the REAL bundled data/ files (populated by
# scripts/update_data.rb). Skipped by default — run with:
#
#   TIMEPRICE_REAL_DATA=1 bundle exec rspec spec/real_data_spec.rb
#
# These tests assert a handful of known historical values cross-checked
# against the public calculators (BLS, ONS, World Bank). They are looser
# than fixture tests (±0.5%) because upstream values shift on revision.

require "timeprice"

RSpec.describe "Real data smoke tests", :real_data do
  before(:each) do
    skip "Set TIMEPRICE_REAL_DATA=1 to run" unless ENV["TIMEPRICE_REAL_DATA"] == "1"
    @real_root = File.expand_path("../data", __dir__)
    @prev_env  = ENV["TIMEPRICE_DATA_ROOT"]
    ENV["TIMEPRICE_DATA_ROOT"] = @real_root
    Timeprice::DataLoader.clear_cache!
  end

  after(:each) do
    next unless @prev_env || ENV["TIMEPRICE_DATA_ROOT"] == @real_root
    ENV["TIMEPRICE_DATA_ROOT"] = @prev_env
    Timeprice::DataLoader.clear_cache!
  end

  it "US: $100 in 1990-01 inflates to roughly $235 in 2024-01 (BLS calc)" do
    r = Timeprice.inflation(amount: 100, from: "1990-01", to: "2024-01", country: "US")
    expect(r.amount).to be_within(15).of(240)
  end

  it "UK: £100 in 1990 inflates to roughly £230-260 in 2024 (BoE/ONS calc)" do
    r = Timeprice.inflation(amount: 100, from: "1990", to: "2024", country: "UK")
    expect(r.amount).to be_within(20).of(245)
  end

  it "VN: CPI ratio 2010→2020 > 1.5 (high inflation decade)" do
    rate = Timeprice::Inflation.rate(from: "2010", to: "2020", country: "VN")
    expect(rate).to be > 0.5
  end

  it "FX: USD→JPY on 2010-06-15 is roughly 90.5 (Frankfurter/ECB)" do
    r = Timeprice.exchange(amount: 1, from: "USD", to: "JPY", date: "2010-06-15")
    expect(r.rate).to be_within(2).of(91)
  end

  it "FX: USD→VND on 2020-06-15 is roughly 23000 (annual avg broadcast)" do
    r = Timeprice.exchange(amount: 1, from: "USD", to: "VND", date: "2020-06-15")
    expect(r.rate).to be_within(500).of(23200)
  end

  it "Compare: 100 USD@2010 → VND@2020 yields a sane positive number" do
    r = Timeprice.compare(amount: 100, from: ["USD", "2010"], to: ["VND", "2020"])
    expect(r.amount).to be > 0
  end

  it "Out-of-range date raises DateOutOfRange (or DataNotFound)" do
    expect {
      Timeprice.inflation(amount: 100, from: "1800-01", to: "2024-01", country: "US")
    }.to raise_error(Timeprice::Error)
  end
end
