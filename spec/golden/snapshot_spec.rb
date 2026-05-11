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

  around(:each) do |ex|
    prev = ENV["TIMEPRICE_DATA_ROOT"]
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

  it "VN: CPI ratio 2010 → 2020 (World Bank FP.CPI.TOTL)" do
    # Bundled annual: 2010 = 100.0, 2020 ≈ 168.7837214833...
    # rate = 168.7837214833 / 100 - 1 ≈ 0.687837...
    # Cross-check: World Bank's published series for Vietnam shows CPI roughly
    # 1.69× over 2010-2020 — high-inflation decade with reform-era pricing.
    rate = Timeprice::Inflation.rate(from: "2010", to: "2020", country: "VN")
    expect(rate.round(6)).to eq(0.687837)
  end

  it "Compare: 100 USD @ 2010 → VND @ 2024" do
    # Bundled values used by the library:
    #   FX USD→VND on 2010-06-30 (year-anchor) = 18612.92
    #   VN CPI 2010 = 100.0, 2024 ≈ 189.702668041402
    #   converted_2010 = 100 * 18612.92 = 1_861_292.0 VND
    #   inflated       = 1_861_292.0 * (189.702668041402 / 100.0)
    #                  = 3_530_920.5840411717...
    # Cross-check: order-of-magnitude sanity — 100 USD in 2010 is roughly
    # 1.86M VND nominal, and Vietnam's 14-year CPI ratio is ~1.9x.
    r = Timeprice.compare(amount: 100, from: ["USD", "2010"], to: ["VND", "2024"])
    expect(r.amount.round(2)).to eq(3_530_920.58)
    expect(r.fx_rate).to eq(18612.92)
    expect(r.country).to eq("VN")
  end
end
