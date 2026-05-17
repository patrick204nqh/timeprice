# frozen_string_literal: true

require "rake"

RSpec.describe "rake forecast:backtest" do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake.application = Rake::Application.new
    Rake.application.rake_require("forecast", [File.expand_path("../../rakelib", __dir__)])
    Rake::Task.define_task(:environment)
  end

  it "reports MAPE per country at +1y / +3y / +5y horizons and stays under a sane ceiling for US" do
    real_data_root = File.expand_path("../../data", __dir__)
    saved_env = ENV.delete("TIMEPRICE_DATA_ROOT")
    Timeprice::DataLoader.data_root = real_data_root
    Rake::Task["forecast:backtest"].invoke
  ensure
    ENV["TIMEPRICE_DATA_ROOT"] = saved_env if saved_env
    Timeprice::DataLoader.data_root = Timeprice::DataLoader::DEFAULT_DATA_ROOT
    summary = Timeprice::Forecast::Backtest.last_summary
    expect(summary).to be_a(Hash)

    us = summary["US"]
    expect(us).to include(:mape_1y, :mape_3y, :mape_5y)
    # US CPI is the most stable series we ship. 5y MAPE should clear ≤15%.
    expect(us[:mape_5y]).to be < 0.15
  end
end
