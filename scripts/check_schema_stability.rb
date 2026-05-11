#!/usr/bin/env ruby
# frozen_string_literal: true

# Schema-stability gate (PLAN.md §9.4 #5).
#
# Asserts that every bundled data file has exactly the expected top-level
# keys per §2a. New keys would be a schema change requiring a deliberate
# `schema_version` bump and code review — not a silent data refresh.
#
# Exits 0 on success. Exits 1 with a diff message on any mismatch.

require "json"

ROOT = File.expand_path("..", __dir__)
DATA = File.join(ROOT, "data")

CPI_KEYS = %w[annual base_year country monthly provenance providers schema_version source updated_at].freeze
# FX `annual` is optional — present only for currencies sourced at annual
# resolution (World Bank VND); pure-daily files (e.g. 2025) won't carry it.
FX_REQUIRED_KEYS = %w[base rates schema_version source updated_at year].freeze
FX_OPTIONAL_KEYS = %w[annual].freeze

failures = []

check = lambda do |path, required, optional = []|
  begin
    parsed = JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    failures << "#{path}: invalid JSON (#{e.message})"
    return
  end

  actual = parsed.keys
  missing = required - actual
  extra   = actual - required - optional
  next if missing.empty? && extra.empty?

  failures << "#{path}: top-level key mismatch\n  " \
              "required: #{required.sort.inspect}\n  " \
              "optional: #{optional.sort.inspect}\n  " \
              "actual:   #{actual.sort.inspect}\n  " \
              "missing:  #{missing.inspect}\n  " \
              "extra:    #{extra.inspect}"
end

Dir[File.join(DATA, "cpi", "*.json")].each do |p|
  # Skip a possible placeholder during early bootstrap.
  next if File.basename(p) == "placeholder.json"

  check.call(p, CPI_KEYS)
end

Dir[File.join(DATA, "fx", "usd", "*.json")].each do |p|
  check.call(p, FX_REQUIRED_KEYS, FX_OPTIONAL_KEYS)
end

if failures.empty?
  puts "Schema stability OK: all data files match expected top-level keys."
  exit 0
else
  warn "Schema stability FAILED:"
  failures.each { |f| warn f }
  exit 1
end
