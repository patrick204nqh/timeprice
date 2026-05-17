# frozen_string_literal: true

require "timeprice"

RSpec.describe Timeprice::Compare, ".series_for" do
  it "returns measured points keyed by year for available CPI data" do
    points = described_class.series_for(
      from: %w[USD 2010], to: %w[VND 2020], forecast: false
    )
    expect(points).not_to be_empty
    points.each do |p|
      expect(p[:measured]).to be true
      expect(p[:date]).to match(/\A\d{4}-01\z/)
      expect(p[:amount]).to be > 0
    end
    # First and last anchor to from/to years when the data point exists.
    expect(points.first[:date]).to start_with("2010")
    expect(points.last[:date]).to start_with("2020")
  end

  it "tags forecast years and adds low/high band when forecast: true" do
    points = described_class.series_for(
      from: %w[USD 2010], to: %w[VND 2030], forecast: true, amount: 100
    )
    measured, forecast = points.partition { |p| p[:measured] }
    expect(measured).not_to be_empty
    expect(forecast).not_to be_empty
    forecast.each do |p|
      expect(p[:low]).to  be <= p[:amount]
      expect(p[:high]).to be >= p[:amount]
      expect(p[:amount]).to be > 0
    end
    last_measured_year = measured.last[:date].slice(0, 4).to_i
    first_forecast_year = forecast.first[:date].slice(0, 4).to_i
    expect(first_forecast_year).to be > last_measured_year
  end

  it "returns a single point when from and to are the same year" do
    points = described_class.series_for(
      from: %w[USD 2010], to: %w[VND 2010], forecast: false
    )
    expect(points.size).to eq(1)
    expect(points.first[:measured]).to be true
  end
end
