# frozen_string_literal: true

# Entry point for the monthly data refresh. Wraps each source so a failure
# in one doesn't abort the rest. Exits 0 only if at least FX + US succeed.

require_relative "_common"
require_relative "frankfurter"
require_relative "bls"
require_relative "world_bank"
require_relative "ons"
require_relative "eurostat"
require_relative "estat"
require_relative "imf"
require_relative "abs"
require_relative "statcan"
require_relative "manifest"

module Tools
  module DataPipeline
    class Runner
      # Map fetcher display name → source file path. Used in GitHub
      # `::warning file=...::` annotations so failures surface next to
      # the responsible source.
      SOURCE_FILES = {
        "Frankfurter" => "tools/data_pipeline/frankfurter.rb",
        "World Bank VND FX" => "tools/data_pipeline/world_bank.rb",
        "BLS" => "tools/data_pipeline/bls.rb",
        "World Bank VN CPI" => "tools/data_pipeline/world_bank.rb",
        "World Bank AU CPI baseline" => "tools/data_pipeline/world_bank.rb",
        "World Bank CA CPI baseline" => "tools/data_pipeline/world_bank.rb",
        "World Bank KR CPI baseline" => "tools/data_pipeline/world_bank.rb",
        "World Bank CN CPI" => "tools/data_pipeline/world_bank.rb",
        "World Bank RU CPI" => "tools/data_pipeline/world_bank.rb",
        "ONS" => "tools/data_pipeline/ons.rb",
        "Eurostat" => "tools/data_pipeline/eurostat.rb",
        "e-Stat / JP" => "tools/data_pipeline/estat.rb",
        "IMF / VN" => "tools/data_pipeline/imf.rb",
        "IMF / KR" => "tools/data_pipeline/imf.rb",
        "IMF / CN" => "tools/data_pipeline/imf.rb",
        "IMF / RU" => "tools/data_pipeline/imf.rb",
        "IMF / RU FX" => "tools/data_pipeline/imf.rb",
        "ABS / AU" => "tools/data_pipeline/abs.rb",
        "StatCan / CA" => "tools/data_pipeline/statcan.rb",
      }.freeze

      def self.run
        new.run
      end

      def initialize
        @results = {}
      end

      def run
        run_fx
        run_cpi_baselines
        run_cpi_layers
        finalise
        summary
        critical_ok? ? 0 : 1
      end

      private

      def run_fx
        run_one("Frankfurter") { Tools::DataPipeline::Frankfurter.run }
        run_one("World Bank VND FX") { Tools::DataPipeline::WorldBank.run_vnd_fx }
        run_one("IMF / RU FX") { Tools::DataPipeline::IMF.run_ru_fx }
      end

      def run_cpi_baselines
        run_one("BLS") { Tools::DataPipeline::BLS.run }
        run_one("World Bank VN CPI") { Tools::DataPipeline::WorldBank.run_vn_cpi }
        run_one("World Bank AU CPI baseline") { Tools::DataPipeline::WorldBank.run_au_cpi_fallback }
        run_one("World Bank CA CPI baseline") { Tools::DataPipeline::WorldBank.run_ca_cpi_fallback }
        run_one("World Bank KR CPI baseline") { Tools::DataPipeline::WorldBank.run_kr_cpi_fallback }
        run_one("World Bank CN CPI") { Tools::DataPipeline::WorldBank.run_cn_cpi }
        run_one("World Bank RU CPI") { Tools::DataPipeline::WorldBank.run_ru_cpi }
      end

      def run_cpi_layers
        # Higher-fidelity monthly/quarterly layers — each merges via CountryFile
        # on top of the annual baseline. Best-effort: a failure here still
        # leaves valid annual-only data on disk.
        run_one("IMF / VN") { Tools::DataPipeline::IMF.run_vn_cpi }
        run_one("IMF / KR") { Tools::DataPipeline::IMF.run_kr_cpi }
        run_one("IMF / CN") { Tools::DataPipeline::IMF.run_cn_cpi }
        run_one("IMF / RU") { Tools::DataPipeline::IMF.run_ru_cpi }
        run_one("ABS / AU") { Tools::DataPipeline::ABS.run }
        run_one("StatCan / CA") { Tools::DataPipeline::StatCan.run }
        # KOSIS intentionally not wired up — KR monthly CPI is sourced from IMF
        # (KOR.CPI._T.IX.M). Re-add when KOSIS_API_KEY support lands.
        run_one("ONS") { Tools::DataPipeline::ONS.run }
        run_one("Eurostat") { Tools::DataPipeline::Eurostat.run }
        run_one("e-Stat / JP") { Tools::DataPipeline::EStat.run }
      end

      def finalise
        # Remove the placeholder once any real CPI lands.
        placeholder = File.join(Tools::DataPipeline::DATA_ROOT, "cpi", "placeholder.json")
        FileUtils.rm_f(placeholder)
        # Regenerate the manifest from whatever the fetchers produced. Always
        # run, even if some fetchers failed — the manifest reflects on-disk
        # truth.
        run_one("Manifest") { Tools::DataPipeline::Manifest.write }
      end

      def run_one(name)
        yield
        @results[name] = :ok
      rescue StandardError => e
        @results[name] = annotate_failure(name, e)
      end

      def annotate_failure(name, error)
        msg = "#{name}: FAILED — #{error.class}: #{error.message}"
        Tools::DataPipeline.log msg
        file = SOURCE_FILES[name]
        title = "Fetcher failed: #{name}"
        safe = "#{error.class}: #{error.message}".gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
        warn(file ? "::warning file=#{file},title=#{title}::#{safe}" : "::warning title=#{title}::#{safe}")
        msg
      end

      def summary
        puts ""
        puts "=== Summary ==="
        @results.each { |name, val| puts(val == :ok ? "#{name}: OK" : val) }
        puts "=== End Summary ==="
      end

      def critical_ok?
        @results["Frankfurter"] == :ok && @results["BLS"] == :ok
      end
    end
  end
end

exit(Tools::DataPipeline::Runner.run) if __FILE__ == $PROGRAM_NAME
