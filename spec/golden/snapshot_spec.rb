# frozen_string_literal: true

#
# Golden snapshot tests against the REAL bundled data/ files (not fixtures).
#
# These are regression guards on the library's math: each expected value is
# derived directly from the bundled data, so they assert "the library performs
# the right math against THIS data," not "the data matches a third-party
# calculator." Independent cross-checks (BLS / BoE / World Bank calculators)
# are noted in comments per expected value.
#
# Run in the default suite — they should always pass against committed data.

RSpec.describe "golden snapshots (real bundled data)" do
  REAL_DATA_ROOT = File.expand_path("../../data", __dir__)

  around do |ex|
    prev = ENV.fetch("TIMEPRICE_DATA_ROOT", nil)
    ENV["TIMEPRICE_DATA_ROOT"] = REAL_DATA_ROOT
    Timeprice::DataLoader.clear_cache!
    begin
      ex.run
    ensure
      ENV["TIMEPRICE_DATA_ROOT"] = prev
      Timeprice::DataLoader.clear_cache!
    end
  end

  it "US: 100 USD 1990-01 → 2024-01 (BLS CPI-U)" do
    # Bundled CPI: 1990-01 = 127.4, 2024-01 = 308.417
    # 100 * 308.417 / 127.4 = 242.08555729...
    # Cross-check: BLS public calculator returns ≈ $241-$242 for this pair.
    r = Timeprice.inflation(amount: 100, from: "1990-01", to: "2024-01", country: "US")
    expect(r.amount.round(4)).to eq(242.0856)
    expect(r.granularity).to eq(:monthly)
  end

  it "UK: 100 GBP 1990 → 2024 (ONS D7BT annual)" do
    # Bundled CPI annual: 1990 = 55.9, 2024 = 133.9
    # 100 * 133.9 / 55.9 = 239.53488372093...
    # Cross-check: BoE inflation calculator reports £100 in 1990 worth roughly
    # £245 in 2024 (different basket assumptions account for the spread).
    r = Timeprice.inflation(amount: 100, from: "1990", to: "2024", country: "UK")
    expect(r.amount.round(4)).to eq(239.5349)
    expect(r.granularity).to eq(:annual)
  end

  it "VN: CPI ratio 2010 → 2020 (IMF Data Portal CPI dataflow)" do
    # Bundled annual (IMF-derived from monthly): 2010 ≈ 52.492, 2020 ≈ 88.597
    # rate = 88.597 / 52.492 - 1 ≈ 0.687819
    # Cross-check: World Bank's annual series shows ratio ≈ 1.688 over the same
    # window — IMF's monthly-derived figures match to ~0.001% (different rebase
    # cycle of the index, identical underlying inflation).
    rate = Timeprice::Inflation.rate(from: "2010", to: "2020", country: "VN")
    # Tolerance absorbs the ~0.001% rebase drift each IMF refresh re-emits; a
    # real regression in the inflation math would move this by orders of
    # magnitude more.
    expect(rate).to be_within(0.001).of(0.687819)
  end

  it "Compare: 100 USD @ 2010 → VND @ 2024" do
    # Bundled values used by the library:
    #   FX USD→VND on 2010-06-30 (year-anchor) = 18612.92
    #   VN CPI 2010 ≈ 52.492, 2024 ≈ 99.578 (IMF Data Portal; ratio ≈ 1.8970)
    #   converted_2010 = 100 * 18612.92 = 1_861_292.0 VND
    #   inflated       = 1_861_292.0 * (99.578 / 52.492)
    #                  ≈ 3_530_894.89
    # Cross-check: order-of-magnitude sanity — 100 USD in 2010 is roughly
    # 1.86M VND nominal, and Vietnam's 14-year CPI ratio is ~1.9x.
    r = Timeprice.compare(amount: 100, from: %w[USD 2010], to: %w[VND 2024])
    # Tolerance (±100 VND on ~3.5M) absorbs IMF refresh drift in the CPI ratio.
    # FX is annual-locked from World Bank, so it stays exact.
    expect(r.amount).to be_within(100).of(3_530_894.89)
    expect(r.fx_rate).to eq(18_612.92)
    expect(r.country).to eq("VN")
  end
end
