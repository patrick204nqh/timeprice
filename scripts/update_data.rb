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

results = {}

run = lambda { |name, &blk|
  print_name = name.to_s
  begin
    blk.call
    results[print_name] = :ok
  rescue StandardError => e
    msg = "#{print_name}: FAILED — #{e.class}: #{e.message}"
    Sources.log msg
    results[print_name] = msg
  end
}

# FX first (so VN/WB step has files to merge VND into), then CPIs.
run.call("Frankfurter") { Sources::Frankfurter.run }
run.call("World Bank VND FX") { Sources::WorldBank.run_vnd_fx }
run.call("BLS") { Sources::BLS.run }
run.call("World Bank VN CPI") { Sources::WorldBank.run_vn_cpi }
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
