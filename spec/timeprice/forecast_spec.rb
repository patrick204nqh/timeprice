# frozen_string_literal: true

RSpec.describe Timeprice, ".forecast" do
  it "dispatches to CpiForecaster when kind: :cpi" do
    result = described_class.forecast(kind: :cpi, country: "US", target: "2030")
    expect(result.basis_kind).to eq(:cpi)
    expect(result.last_known_date).to match(/\A\d{4}(-\d{2})?\z/)
    expect(result.value).to be > 0
    expect(result.low).to be <= result.value
    expect(result.high).to be >= result.value
    expect(result.projection_method).to eq("cagr_trailing")
  end

  it "dispatches to FxForecaster when kind: :fx" do
    real_root = File.expand_path("../../data", __dir__)
    saved_env = ENV.delete("TIMEPRICE_DATA_ROOT")
    Timeprice::DataLoader.data_root = real_root

    result = described_class.forecast(kind: :fx, from: "USD", to: "VND", target: "2026")
    expect(result.basis_kind).to eq(:fx)
    expect(result.value).to be > 0
  ensure
    ENV["TIMEPRICE_DATA_ROOT"] = saved_env if saved_env
    Timeprice::DataLoader.data_root = nil
  end

  it "raises ArgumentError for unknown kind" do
    expect { described_class.forecast(kind: :bogus, target: "2030") }
      .to raise_error(ArgumentError, /kind/)
  end

  it "raises ArgumentError when kind: :cpi lacks country" do
    expect { described_class.forecast(kind: :cpi, target: "2030") }
      .to raise_error(ArgumentError, /country/)
  end

  it "raises ArgumentError when kind: :fx lacks from/to" do
    expect { described_class.forecast(kind: :fx, target: "2030") }
      .to raise_error(ArgumentError, /from.*to|to.*from/)
  end
end
