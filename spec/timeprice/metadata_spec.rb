# frozen_string_literal: true

RSpec.describe Timeprice::Metadata do
  let(:meta) { Timeprice.metadata }

  it "carries the gem version and manifest generated_at" do
    expect(meta[:version]).to eq(Timeprice::VERSION)
    expect(meta[:generated_at]).to match(/\A\d{4}-\d{2}-\d{2}\z/)
  end

  it "lists every supported country with display name, currency, and CPI range" do
    codes = meta[:countries].map { |c| c[:code] }
    expect(codes).to match_array(Timeprice::Supported.countries)

    us = meta[:countries].find { |c| c[:code] == "US" }
    expect(us[:name]).to eq("United States")
    expect(us[:currency]).to eq("USD")
    expect(us[:granularities]).to include("monthly", "annual")
    expect(us[:cpi][:monthly][:min]).to match(/\A\d{4}-\d{2}\z/)
    expect(us[:cpi][:monthly][:max]).to match(/\A\d{4}-\d{2}\z/)
  end

  it "exposes only the granularities a country actually ships" do
    au = meta[:countries].find { |c| c[:code] == "AU" }
    expect(au[:cpi]).to have_key(:annual)
    expect(au[:cpi]).to have_key(:quarterly)
    expect(au[:cpi]).not_to have_key(:monthly)
  end

  it "lists every currency with a display name" do
    codes = meta[:currencies].map { |c| c[:code] }
    expect(codes).to match_array(Timeprice::Supported.currencies)
    expect(meta[:currencies]).to all(include(:code, :name))
  end

  it "reports FX coverage from the actual daily rate files" do
    fx = meta[:fx]
    expect(fx[:base]).to eq("USD")
    expect(fx[:daily_min]).to match(/\A\d{4}-\d{2}-\d{2}\z/)
    expect(fx[:daily_max]).to match(/\A\d{4}-\d{2}-\d{2}\z/)
    expect(fx[:daily_min]).to be < fx[:daily_max]
  end

  it "returns a deeply frozen, JSON-serialisable structure" do
    expect(meta).to be_frozen
    expect(meta[:countries]).to be_frozen
    expect(meta[:countries].first).to be_frozen
    expect { JSON.generate(meta) }.not_to raise_error
  end
end
