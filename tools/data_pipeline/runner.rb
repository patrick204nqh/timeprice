# frozen_string_literal: true

# Entry point for the monthly data refresh. Wraps each source so a failure
# in one doesn't abort the rest. Exits 0 only if at least FX + US succeed.

require_relative "_common"
require_relative "frankfurter"
require_relative "bls"
require_relative "world_bank"
require_relative "ons"
require_relative "eurostat"
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
      # Module-level CPI orchestrators (not Provider subclasses themselves).
      # Empty after dropping the e-Stat fallback. Kept as a hash so future
      # keyless module-level orchestrators can slot in here.
      MODULE_CPI_RUNS = {}.freeze
      CRITICAL_NAMES = %w[Frankfurter].freeze
      FILE_HINTS = {
        "Frankfurter" => File.expand_path("frankfurter.rb", __dir__),
        "World Bank VND FX" => File.expand_path("world_bank.rb", __dir__),
        "IMF / RU FX" => File.expand_path("imf.rb", __dir__),
        "Manifest" => File.expand_path("manifest.rb", __dir__),
      }.freeze

      def self.run
        new.run
      end

      def initialize
        @results = {}
        @manifest_drift = []
      end

      def run
        run_fx
        run_registered_providers
        run_module_cpis
        finalise
        @manifest_drift = manifest_drift_set
        annotate_manifest_drift(@manifest_drift)
        summary
        critical_ok? && @manifest_drift.empty? ? 0 : 1
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

      # Any new fallback path (e.g. provider A fails -> use provider B) MUST also
      # emit a GitHub ::warning via `annotate_failure` or an equivalent helper,
      # so degraded runs are visible in PR check output rather than only in logs.
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
        if @manifest_drift.any?
          puts ""
          puts "Manifest drift: registered providers whose country is missing from data/manifest.json:"
          @manifest_drift.each { |entry| puts "  - #{entry[:label]} (country=#{entry[:country]})" }
        end
        puts "=== End Summary ==="
      end

      # Set of registered Provider country codes that did *not* land in
      # the freshly written manifest. Each entry is a hash with the
      # provider's display label, country code, and source file (for the
      # GitHub annotation).
      def manifest_drift_set
        manifest_path = File.join(Tools::DataPipeline::DATA_ROOT, "manifest.json")
        return [] unless File.exist?(manifest_path)

        manifest = JSON.parse(File.read(manifest_path))
        # Manifest stores country codes upcased (Timeprice::Schema.dump_cpi
        # upcases the country field); Provider.country_code is whatever the
        # subclass passed to `configure` (lowercase by current convention).
        # Normalise both sides before comparing, otherwise every registered
        # provider gets falsely flagged as drift and the runner exits 1.
        present = Array(manifest["countries"]).map { |c| c["code"]&.upcase }.compact
        Provider.registry.filter_map do |klass|
          code = klass.country_code
          next if code.nil? || present.include?(code.upcase)

          {
            label: label_for(klass),
            country: code,
            file: klass.source_file&.sub("#{REPO_ROOT}/", ""),
          }
        end
      end

      # Emit a ::error annotation per missing country so the PR check
      # surface flags drift more loudly than the per-fetcher ::warning.
      def annotate_manifest_drift(drift)
        return if drift.empty?

        drift.each do |entry|
          title = "Manifest drift: #{entry[:label]}"
          body  = "Registered provider for country #{entry[:country]} produced no entry in data/manifest.json. " \
                  "Re-run the fetcher locally, confirm data/cpi/#{entry[:country].downcase}.json exists, " \
                  "and check that the country code is in tools/data_pipeline/_common.rb COUNTRY_TO_CURRENCY."
          safe  = body.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
          line  = entry[:file] ? "::error file=#{entry[:file]},title=#{title}::#{safe}" : "::error title=#{title}::#{safe}"
          Tools::DataPipeline.log "#{entry[:label]}: MANIFEST DRIFT — country #{entry[:country]} missing from manifest"
          warn line
        end
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
