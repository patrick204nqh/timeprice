# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Timeprice::DataLoader do
  it "refuses unknown schema_version" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "cpi"))
      File.write(File.join(dir, "cpi", "zz.json"),
        JSON.dump({ "schema_version" => 999, "country" => "ZZ", "monthly" => {}, "annual" => {} }))

      old = ENV["TIMEPRICE_DATA_ROOT"]
      begin
        ENV["TIMEPRICE_DATA_ROOT"] = dir
        described_class.clear_cache!
        expect { described_class.load_cpi("ZZ") }
          .to raise_error(Timeprice::UnsupportedSchemaVersion) { |e|
            expect(e.version).to eq(999)
          }
      ensure
        ENV["TIMEPRICE_DATA_ROOT"] = old
        described_class.clear_cache!
      end
    end
  end

  it "raises UnsupportedCountry when CPI file missing" do
    expect { described_class.load_cpi("ZZ") }
      .to raise_error(Timeprice::UnsupportedCountry, /ZZ/)
  end

  it "honors TIMEPRICE_DATA_ROOT env var" do
    expect(described_class.data_root).to eq(File.expand_path("../fixtures", __dir__))
  end
end
