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
      REPO_ROOT = File.expand_path("../..", __dir__)
      # Hand-orchestrated FX runs: they don't go through Provider (they
      # write FX files, not CPI files) so they aren't in Provider.registry.
      FX_RUNS = {
        "Frankfurter" => -> { Tools::DataPipeline::Frankfurter.run },
        "World Bank VND FX" => -> { Tools::DataPipeline::WorldBank.run_vnd_fx },
        "IMF / RU FX" => -> { Tools::DataPipeline::IMF.run_ru_fx },
      }.freeze
      # Module-level CPI orchestrators (not Provider subclasses themselves)
      # — these run after the registry sweep so their fallback paths see
      # whatever the registered providers wrote.
      MODULE_CPI_RUNS = {
        "e-Stat / JP" => -> { Tools::DataPipeline::EStat.run },
      }.freeze
      CRITICAL_NAMES = %w[Frankfurter].freeze
      FILE_HINTS = {
        "Frankfurter" => File.expand_path("frankfurter.rb", __dir__),
        "World Bank VND FX" => File.expand_path("world_bank.rb", __dir__),
        "IMF / RU FX" => File.expand_path("imf.rb", __dir__),
        "e-Stat / JP" => File.expand_path("estat.rb", __dir__),
        "Manifest" => File.expand_path("manifest.rb", __dir__),
      }.freeze

      def self.run
        new.run
      end

      def initialize
        @results = {}
      end

      def run
        run_fx
        run_registered_providers
        run_module_cpis
        finalise
        summary
        critical_ok? ? 0 : 1
      end

      private

      def run_fx
        FX_RUNS.each { |name, callable| run_one(name) { callable.call } }
      end

      def run_registered_providers
        # Stable sort: priority first, registry insertion order second.
        # Ruby's sort_by is not formally stable, so include the index
        # explicitly to lock the within-priority order.
        ordered = Provider.registry
                          .each_with_index
                          .sort_by { |klass, idx| [klass.priority, idx] }
                          .map { |klass, _| klass }
        ordered.each do |klass|
          run_one(label_for(klass)) { klass.run }
        end
      end

      def run_module_cpis
        MODULE_CPI_RUNS.each { |name, callable| run_one(name) { callable.call } }
      end

      def finalise
        placeholder = File.join(Tools::DataPipeline::DATA_ROOT, "cpi", "placeholder.json")
        FileUtils.rm_f(placeholder)
        run_one("Manifest") { Tools::DataPipeline::Manifest.write }
      end

      # Display name for a Provider subclass. Combines the upstream
      # nickname (log_label) with the country it writes — readable in the
      # ::warning annotation and the summary.
      def label_for(provider_class)
        "#{provider_class.log_label} / #{provider_class.country_code.upcase}"
      end

      def run_one(name)
        yield
        @results[name] = :ok
      rescue StandardError => e
        # Typed Tools::DataPipeline::Error subclasses (HttpError,
        # ShapeError, ValidationError, SchemaError) and any unexpected
        # StandardError land here. We log + continue so one fetcher
        # failing doesn't take down the rest of the chain.
        @results[name] = annotate_failure(name, e)
      end

      def annotate_failure(name, error)
        msg = "#{name}: FAILED — #{error.class}: #{error.message}"
        Tools::DataPipeline.log msg
        file = source_file_for(name)
        title = "Fetcher failed: #{name}"
        safe = "#{error.class}: #{error.message}".gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
        warn(file ? "::warning file=#{file},title=#{title}::#{safe}" : "::warning title=#{title}::#{safe}")
        msg
      end

      # GitHub annotation path. Pulled from Provider.source_file (captured
      # at configure-time) for registered providers; falls back to a
      # hand-coded map for FX / module runs.
      def source_file_for(name)
        registered = Provider.registry.find { |k| label_for(k) == name }
        absolute   = registered&.source_file || FILE_HINTS[name]
        return nil unless absolute

        absolute.sub("#{REPO_ROOT}/", "")
      end

      def summary
        puts ""
        puts "=== Summary ==="
        @results.each { |name, val| puts(val == :ok ? "#{name}: OK" : val) }
        puts "=== End Summary ==="
      end

      # FX-Frankfurter and every Provider flagged `critical: true` must
      # be green; anything else is best-effort.
      def critical_ok?
        critical_results = CRITICAL_NAMES.map { |n| @results[n] }
        critical_results += Provider.registry.select(&:critical?).map { |k| @results[label_for(k)] }
        critical_results.all? { |r| r == :ok }
      end
    end
  end
end

exit(Tools::DataPipeline::Runner.run) if __FILE__ == $PROGRAM_NAME
