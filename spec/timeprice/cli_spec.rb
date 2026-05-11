# frozen_string_literal: true

require "open3"
require "json"

# CLI specs shell out so we exercise the real executable, exit codes, and
# stderr separation. Slower than in-process invocation but the only honest way
# to test "exit 1 with clean stderr" guarantees.
RSpec.describe "timeprice CLI" do
  ROOT = File.expand_path("../..", __dir__)
  EXE  = File.join(ROOT, "exe", "timeprice")
  FIXTURES = File.join(ROOT, "spec", "fixtures")

  def run_cli(*args, data_root: FIXTURES)
    env = { "TIMEPRICE_DATA_ROOT" => data_root, "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile") }
    Open3.capture3(env, "bundle", "exec", EXE, *args, chdir: ROOT)
  end

  REAL_DATA = File.join(ROOT, "data")

  describe "version" do
    it "prints the branded version line" do
      out, err, status = run_cli("version")
      expect(status.exitstatus).to eq(0)
      expect(err).to be_empty
      expect(out).to include("timeprice")
      expect(out).to include("patrick204nqh/timeprice")
    end

    it "supports --json" do
      out, _err, status = run_cli("version", "--json")
      expect(status.exitstatus).to eq(0)
      parsed = JSON.parse(out)
      expect(parsed).to include("version", "repo")
    end
  end

  describe "inflation" do
    it "produces a human-readable line" do
      out, _err, status = run_cli("inflation", "100", "--from", "1990-01", "--to", "2024-01", "--country", "US")
      expect(status.exitstatus).to eq(0)
      expect(out).to match(/100\.00 USD in 1990-01 is .* USD in 2024-01/)
      expect(out).to include("granularity: monthly")
    end

    it "outputs valid JSON with --json and no extra text" do
      out, err, status = run_cli("inflation", "100", "--from", "1990-01", "--to", "2024-01", "--country", "US", "--json")
      expect(status.exitstatus).to eq(0)
      expect(err).to be_empty
      parsed = JSON.parse(out)
      expect(parsed).to include(
        "amount", "original_amount", "from", "to", "country",
        "from_index", "to_index", "granularity"
      )
      expect(parsed["country"]).to eq("US")
    end

    it "exits 1 with a clean stderr for unknown country" do
      out, err, status = run_cli("inflation", "100", "--from", "1990", "--to", "2024", "--country", "ZZ")
      expect(status.exitstatus).to eq(1)
      expect(err).to match(/\AError: /)
      expect(err).not_to include("\n\t")  # no stack trace
      expect(out).to be_empty
    end
  end

  describe "fx" do
    it "produces a human-readable line" do
      out, _err, status = run_cli("fx", "100", "USD", "JPY", "--date", "2010-06-15")
      expect(status.exitstatus).to eq(0)
      expect(out).to match(/100\.00 USD on 2010-06-15 = .* JPY/)
      expect(out).to include("rate:")
    end

    it "notes effective_date when fallback occurred" do
      # 2010-06-13 is Sunday — no data; should fall back to 2010-06-11 (Friday).
      out, _err, status = run_cli("fx", "100", "USD", "JPY", "--date", "2010-06-13")
      expect(status.exitstatus).to eq(0)
      expect(out).to include("effective date: 2010-06-11")
    end

    it "outputs valid JSON with --json" do
      out, _err, status = run_cli("fx", "100", "USD", "JPY", "--date", "2010-06-15", "--json")
      expect(status.exitstatus).to eq(0)
      parsed = JSON.parse(out)
      expect(parsed).to include("amount", "original_amount", "from", "to", "date", "effective_date", "rate")
    end

    it "exits 1 on bad date format with no stack trace" do
      out, err, status = run_cli("fx", "100", "USD", "JPY", "--date", "06/15/2010")
      expect(status.exitstatus).to eq(1)
      expect(err).to match(/\AError: /)
      expect(err).not_to include("/lib/timeprice/")
      expect(out).to be_empty
    end

    it "exits 1 on out-of-range date" do
      _out, err, status = run_cli("fx", "100", "USD", "JPY", "--date", "1995-01-15")
      expect(status.exitstatus).to eq(1)
      expect(err).to match(/\AError: /)
    end
  end

  describe "compare" do
    it "accepts \"YEAR CURRENCY\"" do
      out, _err, status = run_cli("compare", "100", "--from", "2010 USD", "--to", "2024 VND")
      expect(status.exitstatus).to eq(0)
      expect(out).to include("100.00 USD in 2010 -> ")
      expect(out).to include("VND in 2024")
    end

    it "accepts \"CURRENCY YEAR\" (reverse order)" do
      out, _err, status = run_cli("compare", "100", "--from", "USD 2010", "--to", "VND 2024")
      expect(status.exitstatus).to eq(0)
      expect(out).to include("100.00 USD in 2010 -> ")
    end

    it "outputs valid JSON with --json" do
      out, _err, status = run_cli("compare", "100", "--from", "2010 USD", "--to", "2024 VND", "--json")
      expect(status.exitstatus).to eq(0)
      parsed = JSON.parse(out)
      expect(parsed).to include(
        "amount", "original_amount", "from_currency", "from_date",
        "to_currency", "to_date", "country", "fx_rate", "cpi_ratio",
        "converted_amount", "granularity"
      )
    end

    it "exits 1 on malformed tuple" do
      _out, err, status = run_cli("compare", "100", "--from", "garbage", "--to", "2024 VND")
      expect(status.exitstatus).to eq(1)
      expect(err).to match(/\AError: /)
    end
  end

  describe "sources" do
    it "lists all bundled data sources with attribution and coverage" do
      out, err, status = run_cli("sources", data_root: REAL_DATA)
      expect(status.exitstatus).to eq(0)
      expect(err).to be_empty
      expect(out).to include("U.S. Bureau of Labor Statistics")
      expect(out).to include("Open Government Licence v3.0")
      expect(out).to include("Eurostat")
      expect(out).to include("World Bank")
      expect(out).to include("European Central Bank")
      expect(out).to include("attribution:")
      expect(out).to include("coverage:")
    end

    it "outputs valid JSON with --json" do
      out, _err, status = run_cli("sources", "--json", data_root: REAL_DATA)
      expect(status.exitstatus).to eq(0)
      parsed = JSON.parse(out)
      expect(parsed).to be_an(Array)
      expect(parsed.size).to be >= 5
      first = parsed.first
      expect(first).to include("id", "name", "license", "license_url", "attribution", "coverage")
    end
  end
end
