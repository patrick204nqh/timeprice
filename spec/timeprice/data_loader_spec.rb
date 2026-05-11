# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Timeprice::DataLoader do
  it "refuses unknown schema_version" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "cpi"))
      # Use a SUPPORTED country code so the loader gets past the catalog check
      # and actually parses the file.
      File.write(File.join(dir, "cpi", "us.json"),
                 JSON.dump({ "schema_version" => 999, "country" => "US", "monthly" => {}, "annual" => {} }))

      old = ENV.fetch("TIMEPRICE_DATA_ROOT", nil)
      begin
        ENV["TIMEPRICE_DATA_ROOT"] = dir
        described_class.clear_cache!
        expect { described_class.load_cpi("US") }
          .to raise_error(Timeprice::UnsupportedSchemaVersion) { |e|
            expect(e.version).to eq(999)
          }
      ensure
        ENV["TIMEPRICE_DATA_ROOT"] = old
        described_class.clear_cache!
      end
    end
  end

  it "raises UnsupportedCountry for codes not in the catalog" do
    expect { described_class.load_cpi("ZZ") }
      .to raise_error(Timeprice::UnsupportedCountry, /ZZ/)
  end

  it "raises DataNotFound when a supported country's data file is missing" do
    Dir.mktmpdir do |dir|
      # Empty data root — supported country, but the file isn't there.
      old = ENV.fetch("TIMEPRICE_DATA_ROOT", nil)
      begin
        ENV["TIMEPRICE_DATA_ROOT"] = dir
        described_class.clear_cache!
        expect { described_class.load_cpi("US") }
          .to raise_error(Timeprice::DataNotFound, /file missing for US/)
      ensure
        ENV["TIMEPRICE_DATA_ROOT"] = old
        described_class.clear_cache!
      end
    end
  end

  it "honors TIMEPRICE_DATA_ROOT env var" do
    expect(described_class.data_root).to eq(File.expand_path("../fixtures", __dir__))
  end
end
