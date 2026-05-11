#!/usr/bin/env ruby
# frozen_string_literal: true

# Schema-stability gate for schema_version 3.
#
# Asserts every bundled data file has exactly the expected top-level keys
# and that data/manifest.json references every CPI/FX file present. New keys
# require a deliberate `schema_version` bump and code review — not a silent
# data refresh.
#
# Exits 0 on success. Exits 1 with a diff message on any mismatch.

require "json"

ROOT = File.expand_path("..", __dir__)
DATA = File.join(ROOT, "data")
EXPECTED_VERSION = 3

CPI_KEYS = %w[country index provenance providers schema_version series].freeze
FX_YEAR_REQUIRED_KEYS = %w[base provenance providers rates schema_version year].freeze
FX_YEAR_OPTIONAL_KEYS = %w[annual].freeze
FX_ANNUAL_KEYS = %w[annual base provenance providers schema_version].freeze
MANIFEST_KEYS = %w[countries fx generated_at schema_version].freeze

failures = []

assert_schema_version = lambda do |path, parsed|
  v = parsed["schema_version"]
  failures << "#{path}: schema_version is #{v.inspect}, expected #{EXPECTED_VERSION}" unless v == EXPECTED_VERSION
end

check_keys = lambda do |path, parsed, required, optional = []|
  actual = parsed.keys
  missing = required - actual
  extra   = actual - required - optional
  return if missing.empty? && extra.empty?

  failures << "#{path}: top-level key mismatch\n  " \
              "required: #{required.sort.inspect}\n  " \
              "optional: #{optional.sort.inspect}\n  " \
              "actual:   #{actual.sort.inspect}\n  " \
              "missing:  #{missing.inspect}\n  " \
              "extra:    #{extra.inspect}"
end

load = lambda do |path|
  JSON.parse(File.read(path))
rescue JSON::ParserError => e
  failures << "#{path}: invalid JSON (#{e.message})"
  nil
end

# --- manifest ---
manifest_path = File.join(DATA, "manifest.json")
failures << "data/manifest.json missing — required for v3" unless File.exist?(manifest_path)
manifest = File.exist?(manifest_path) ? load.call(manifest_path) : nil
if manifest
  assert_schema_version.call(manifest_path, manifest)
  check_keys.call(manifest_path, manifest, MANIFEST_KEYS)
end

# --- cpi ---
Dir[File.join(DATA, "cpi", "*.json")].each do |p|
  next if File.basename(p) == "placeholder.json"

  parsed = load.call(p)
  next unless parsed

  assert_schema_version.call(p, parsed)
  check_keys.call(p, parsed, CPI_KEYS)
end

# --- fx per-year ---
Dir[File.join(DATA, "fx", "usd", "*.json")].each do |p|
  parsed = load.call(p)
  next unless parsed

  assert_schema_version.call(p, parsed)
  check_keys.call(p, parsed, FX_YEAR_REQUIRED_KEYS, FX_YEAR_OPTIONAL_KEYS)
end

# --- fx annual fallback ---
annual_path = File.join(DATA, "fx", "_annual.json")
if File.exist?(annual_path)
  parsed = load.call(annual_path)
  if parsed
    assert_schema_version.call(annual_path, parsed)
    check_keys.call(annual_path, parsed, FX_ANNUAL_KEYS)
  end
end

# --- manifest references every file present ---
if manifest
  declared_countries = (manifest["countries"] || []).map { |c| c["cpi_file"] }
  on_disk_countries  = Dir[File.join(DATA, "cpi", "*.json")]
                       .reject { |p| File.basename(p) == "placeholder.json" }
                       .map { |p| "cpi/#{File.basename(p)}" }
                       .sort
  missing = on_disk_countries - declared_countries
  extra   = declared_countries - on_disk_countries
  failures << "manifest.countries missing files: #{missing.inspect}" if missing.any?
  failures << "manifest.countries references missing files: #{extra.inspect}" if extra.any?

  declared_years = (manifest.dig("fx", "daily_years") || []).sort
  on_disk_years  = Dir[File.join(DATA, "fx", "usd", "*.json")]
                   .map { |p| File.basename(p, ".json").to_i }
                   .sort
  if declared_years != on_disk_years
    failures << "manifest.fx.daily_years mismatch: declared #{declared_years.inspect} vs on-disk #{on_disk_years.inspect}"
  end
end

if failures.empty?
  puts "Schema stability OK: every data file matches schema v3."
  exit 0
else
  warn "Schema stability FAILED:"
  failures.each { |f| warn f }
  exit 1
end
