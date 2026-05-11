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
require_relative "sources/abs"
require_relative "sources/statcan"
require_relative "sources/kosis"
require_relative "sources/manifest"

results = {}

# Map fetcher display name → source file path (relative to repo root).
# The file path is used in GitHub `::warning file=...::` annotations so that
# fetcher failures show up directly next to the responsible source.
SOURCE_FILES = {
  "Frankfurter" => "scripts/sources/frankfurter.rb",
  "World Bank VND FX" => "scripts/sources/world_bank.rb",
  "BLS" => "scripts/sources/bls.rb",
  "World Bank VN CPI" => "scripts/sources/world_bank.rb",
  "World Bank AU CPI baseline" => "scripts/sources/world_bank.rb",
  "World Bank CA CPI baseline" => "scripts/sources/world_bank.rb",
  "World Bank KR CPI baseline" => "scripts/sources/world_bank.rb",
  "World Bank CN CPI" => "scripts/sources/world_bank.rb",
  "World Bank RU CPI" => "scripts/sources/world_bank.rb",
  "ONS" => "scripts/sources/ons.rb",
  "Eurostat" => "scripts/sources/eurostat.rb",
  "e-Stat / JP" => "scripts/sources/estat.rb",
  "IMF / VN" => "scripts/sources/imf.rb",
  "IMF / KR" => "scripts/sources/imf.rb",
  "IMF / CN" => "scripts/sources/imf.rb",
  "IMF / RU" => "scripts/sources/imf.rb",
  "IMF / RU FX" => "scripts/sources/imf.rb",
  "ABS / AU" => "scripts/sources/abs.rb",
  "StatCan / CA" => "scripts/sources/statcan.rb",
  "KOSIS / KR" => "scripts/sources/kosis.rb",
}.freeze

run = lambda { |name, &blk|
  print_name = name.to_s
  begin
    blk.call
    results[print_name] = :ok
  rescue StandardError => e
    msg = "#{print_name}: FAILED — #{e.class}: #{e.message}"
    Sources.log msg
    file = SOURCE_FILES[print_name]
    annotation_title = "Fetcher failed: #{print_name}"
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
run.call("IMF / RU FX") { Sources::IMF.run_ru_fx }

# CPIs — annual baselines first (cheap), then monthly/quarterly layers.
run.call("BLS") { Sources::BLS.run }
run.call("World Bank VN CPI") { Sources::WorldBank.run_vn_cpi }
run.call("World Bank AU CPI baseline") { Sources::WorldBank.run_au_cpi_fallback }
run.call("World Bank CA CPI baseline") { Sources::WorldBank.run_ca_cpi_fallback }
run.call("World Bank KR CPI baseline") { Sources::WorldBank.run_kr_cpi_fallback }
run.call("World Bank CN CPI") { Sources::WorldBank.run_cn_cpi }
run.call("World Bank RU CPI") { Sources::WorldBank.run_ru_cpi }

# Higher-fidelity monthly/quarterly layers — each merges via CountryFile
# on top of the annual baseline. Best-effort: a failure here still leaves
# valid annual-only data on disk.
run.call("IMF / VN") { Sources::IMF.run_vn_cpi }
run.call("IMF / KR") { Sources::IMF.run_kr_cpi }
run.call("IMF / CN") { Sources::IMF.run_cn_cpi }
run.call("IMF / RU") { Sources::IMF.run_ru_cpi }
run.call("ABS / AU") { Sources::ABS.run }
run.call("StatCan / CA") { Sources::StatCan.run }
run.call("KOSIS / KR") { Sources::KOSIS.run }
run.call("ONS") { Sources::ONS.run }
run.call("Eurostat") { Sources::Eurostat.run }
run.call("e-Stat / JP") { Sources::EStat.run }

# Remove the placeholder once any real CPI lands.
placeholder = File.join(Sources::DATA_ROOT, "cpi", "placeholder.json")
FileUtils.rm_f(placeholder)

# Regenerate the manifest from whatever the fetchers produced. Always run,
# even if some fetchers failed — the manifest reflects on-disk truth.
run.call("Manifest") { Sources::Manifest.write }

puts ""
puts "=== Summary ==="
results.each { |name, val| puts(val == :ok ? "#{name}: OK" : val) }
puts "=== End Summary ==="

critical_ok = results["Frankfurter"] == :ok && results["BLS"] == :ok
exit(critical_ok ? 0 : 1)
