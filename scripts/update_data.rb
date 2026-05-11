# frozen_string_literal: true

# Entry point for the monthly data refresh. Wraps each source so a failure
# in one doesn't abort the rest. Exits 0 only if at least FX + US succeed.

require_relative "sources/_common"
require_relative "sources/frankfurter"
require_relative "sources/bls"
require_relative "sources/world_bank"
require_relative "sources/ons"
require_relative "sources/eurostat"
require_relative "sources/estat"
require_relative "sources/imf"

results = {}

# Map fetcher display name → source file path (relative to repo root).
# The file path is used in GitHub `::warning file=...::` annotations so that
# fetcher failures show up directly next to the responsible source.
SOURCE_FILES = {
  "Frankfurter" => "scripts/sources/frankfurter.rb",
  "World Bank VND FX" => "scripts/sources/world_bank.rb",
  "BLS" => "scripts/sources/bls.rb",
  "World Bank VN CPI" => "scripts/sources/world_bank.rb",
  "ONS" => "scripts/sources/ons.rb",
  "Eurostat" => "scripts/sources/eurostat.rb",
  "e-Stat / JP" => "scripts/sources/estat.rb",
  "IMF / VN" => "scripts/sources/imf.rb",
}.freeze

run = lambda { |name, &blk|
  print_name = name.to_s
  begin
    blk.call
    results[print_name] = :ok
  rescue StandardError => e
    msg = "#{print_name}: FAILED — #{e.class}: #{e.message}"
    Sources.log msg
    # Per-fetcher GitHub Actions annotation. Picked up automatically by the
    # workflow run UI without any extra step. Title carries the fetcher name;
    # `file=` points at the script so the annotation links to the source.
    file = SOURCE_FILES[print_name]
    annotation_title = "Fetcher failed: #{print_name}"
    # Escape per GitHub's rules: %, \r, \n must be encoded in annotation messages.
    safe_msg = "#{e.class}: #{e.message}"
               .gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
    if file
      warn "::warning file=#{file},title=#{annotation_title}::#{safe_msg}"
    else
      warn "::warning title=#{annotation_title}::#{safe_msg}"
    end
    results[print_name] = msg
  end
}

# FX first (so VN/WB step has files to merge VND into), then CPIs.
run.call("Frankfurter") { Sources::Frankfurter.run }
run.call("World Bank VND FX") { Sources::WorldBank.run_vnd_fx }
run.call("BLS") { Sources::BLS.run }
run.call("World Bank VN CPI") { Sources::WorldBank.run_vn_cpi }
# IMF runs AFTER WorldBank for VN: WB writes the annual baseline first,
# IMF layers monthly on top via CountryFile + MergePolicy (provenance
# records which provider supplied each period). If IMF fails, the file
# is still valid with WB-only annual data — non-critical.
run.call("IMF / VN") { Sources::IMF.run }
run.call("ONS") { Sources::ONS.run }
run.call("Eurostat") { Sources::Eurostat.run }
run.call("e-Stat / JP") { Sources::EStat.run }

# Remove the placeholder once any real CPI lands.
placeholder = File.join(Sources::DATA_ROOT, "cpi", "placeholder.json")
FileUtils.rm_f(placeholder)

puts ""
puts "=== Summary ==="
results.each { |name, val| puts(val == :ok ? "#{name}: OK" : val) }
puts "=== End Summary ==="

critical_ok = results["Frankfurter"] == :ok && results["BLS"] == :ok
exit(critical_ok ? 0 : 1)
