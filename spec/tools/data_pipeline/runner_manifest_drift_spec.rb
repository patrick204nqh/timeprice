# frozen_string_literal: true

require "json"
require "fileutils"
require "tmpdir"

require_relative "../../../tools/data_pipeline/runner"

RSpec.describe Tools::DataPipeline::Runner do
  describe "#manifest_drift_set" do
    let(:tmp_data_root) { Dir.mktmpdir("timeprice-manifest-drift") }
    let(:runner) { described_class.new }
    let(:saved_registry) { Tools::DataPipeline::Provider::REGISTRY.dup }

    before do
      # Sandbox DATA_ROOT to a tmp dir so the spec doesn't read the
      # real repo manifest.
      stub_const("Tools::DataPipeline::DATA_ROOT", tmp_data_root)
      # Wipe the registry so the spec can install a controlled fake.
      Tools::DataPipeline::Provider::REGISTRY.clear
    end

    after do
      Tools::DataPipeline::Provider::REGISTRY.clear
      Tools::DataPipeline::Provider::REGISTRY.concat(saved_registry)
      FileUtils.remove_entry(tmp_data_root)
    end

    def fake_provider(country:, log_label: "Fake")
      klass = Class.new(Tools::DataPipeline::Provider) do
        def fetch
          Tools::DataPipeline::Series.build
        end
      end
      klass.configure(
        country_code: country,
        country_label: "Fake #{country}",
        source_label: "Fake source",
        default_base_year: 2020,
        log_label: log_label,
        provider_id: "fake_#{country.downcase}"
      )
      klass
    end

    def write_manifest(country_codes)
      countries = country_codes.map { |code| { "code" => code } }
      File.write(
        File.join(tmp_data_root, "manifest.json"),
        JSON.pretty_generate("countries" => countries)
      )
    end

    it "flags registered providers whose country is missing from manifest" do
      fake_provider(country: "ZZ", log_label: "FakeZZ")
      write_manifest(%w[US UK])

      drift = runner.send(:manifest_drift_set)
      expect(drift.map { |e| e[:country] }).to eq(["ZZ"])
      expect(drift.first[:label]).to include("FakeZZ")
    end

    it "is empty when every registered provider's country is in the manifest" do
      fake_provider(country: "ZZ", log_label: "FakeZZ")
      write_manifest(%w[US ZZ])

      expect(runner.send(:manifest_drift_set)).to be_empty
    end

    it "is empty when the manifest file is missing (treated as a no-op)" do
      fake_provider(country: "ZZ", log_label: "FakeZZ")
      expect(runner.send(:manifest_drift_set)).to be_empty
    end

    it "matches case-insensitively (provider lower-case vs manifest upper-case)" do
      # Manifest writer upcases country codes via Timeprice::Schema.dump_cpi;
      # Provider.country_code is passed lowercase by convention. The drift
      # check must normalise before comparing.
      fake_provider(country: "vn", log_label: "FakeVN")
      write_manifest(%w[VN])

      expect(runner.send(:manifest_drift_set)).to be_empty
    end
  end

  describe "exit code wiring" do
    let(:tmp_data_root) { Dir.mktmpdir("timeprice-manifest-drift-exit") }
    let(:saved_registry) { Tools::DataPipeline::Provider::REGISTRY.dup }

    before do
      stub_const("Tools::DataPipeline::DATA_ROOT", tmp_data_root)
      Tools::DataPipeline::Provider::REGISTRY.clear
    end

    after do
      Tools::DataPipeline::Provider::REGISTRY.clear
      Tools::DataPipeline::Provider::REGISTRY.concat(saved_registry)
      FileUtils.remove_entry(tmp_data_root)
    end

    def install_fake(country:)
      klass = Class.new(Tools::DataPipeline::Provider) do
        def fetch
          Tools::DataPipeline::Series.build
        end
      end
      klass.configure(
        country_code: country,
        country_label: "Fake #{country}",
        source_label: "Fake",
        default_base_year: 2020,
        log_label: "Fake#{country}",
        provider_id: "fake_#{country.downcase}"
      )
      klass
    end

    it "returns non-zero when drift is detected" do
      install_fake(country: "ZZ")
      runner = described_class.new
      # Stub out the run sub-steps so we don't hit the network or
      # write fixture FX/CPI files; only manifest is consulted.
      allow(runner).to receive(:run_fx)
      allow(runner).to receive(:run_registered_providers)
      allow(runner).to receive(:run_module_cpis)
      allow(runner).to receive(:finalise) do
        File.write(
          File.join(tmp_data_root, "manifest.json"),
          JSON.pretty_generate("countries" => [{ "code" => "US" }])
        )
      end
      # Isolate the drift signal: criticals OK, but ZZ is missing.
      runner.instance_variable_get(:@results)["Frankfurter"] = :ok

      expect { @code = runner.run }.to output(/Manifest drift/).to_stdout
      expect(@code).to eq(1)
    end

    it "returns zero when the registered provider's country is in the manifest" do
      install_fake(country: "ZZ")
      runner = described_class.new
      allow(runner).to receive(:run_fx)
      allow(runner).to receive(:run_registered_providers)
      allow(runner).to receive(:run_module_cpis)
      allow(runner).to receive(:finalise) do
        File.write(
          File.join(tmp_data_root, "manifest.json"),
          JSON.pretty_generate("countries" => [{ "code" => "ZZ" }])
        )
      end
      # critical_ok? scans @results for CRITICAL_NAMES (Frankfurter) +
      # any registered :critical providers. Mark them OK so this spec
      # isolates the drift-vs-exit-code wiring.
      results = runner.instance_variable_get(:@results)
      results["Frankfurter"] = :ok

      expect(runner.run).to eq(0)
    end
  end
end
