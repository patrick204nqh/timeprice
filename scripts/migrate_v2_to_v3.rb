#!/usr/bin/env ruby
# frozen_string_literal: true

# One-time migration of timeprice bundled data from schema v2 to schema v3.
#
# Run once per data tree:
#
#   ruby scripts/migrate_v2_to_v3.rb               # against ./data
#   TIMEPRICE_DATA_ROOT=/path ruby scripts/migrate_v2_to_v3.rb
#
# What it does:
#   - Rewrites every data/cpi/*.json into v3 shape (series.{monthly,annual},
#     structured `index`, drops top-level `source`/`updated_at`).
#   - Rewrites every data/fx/usd/*.json into v3 shape (adds provenance + providers
#     blocks, drops top-level `source`/`updated_at`).
#   - Collapses pre-1990 stub files (any year file with `rates: {}` and only
#     `annual`) into a new data/fx/_annual.json, then deletes the stubs.
#   - Writes data/manifest.json as the single source of truth for the
#     supported set.
#
# Idempotent: re-running on an already-v3 tree is a no-op (schema_version is
# checked and skipped if already 3).

require "json"
require "date"
require "fileutils"
require_relative "sources/_common"

# rubocop:disable Metrics/ModuleLength
# Single-purpose one-shot migration; keeping it as one self-contained module
# is more readable than splitting for the sake of a length cop.
module MigrateV2ToV3
  DATA_ROOT = ENV["TIMEPRICE_DATA_ROOT"] ||
              File.expand_path("../data", __dir__)

  BASE_YEAR_RE = Sources::BASE_YEAR_RE
  COUNTRY_TO_CURRENCY = Sources::COUNTRY_TO_CURRENCY

  CPI_FILES = "cpi/*.json"
  FX_USD_FILES = "fx/usd/*.json"
  ANNUAL_FALLBACK_FILE = "fx/_annual.json"
  MANIFEST_FILE = "manifest.json"

  module_function

  def run
    log "data root: #{DATA_ROOT}"
    migrate_cpi_files
    migrate_fx_files
    write_manifest
    log "done."
  end

  # ---------- CPI ----------

  def migrate_cpi_files
    Dir[File.join(DATA_ROOT, CPI_FILES)].each do |path|
      data = JSON.parse(File.read(path))
      next skip(path) if data["schema_version"] == 3

      v3 = build_cpi_v3(data)
      write_json(path, v3)
      log "cpi: rewrote #{File.basename(path)}"
    end
  end

  def build_cpi_v3(v2)
    {
      "schema_version" => 3,
      "country" => v2["country"],
      "index" => parse_base_year(v2["base_year"]),
      # Uniform shape: both granularities always present (`{}` if empty, e.g. JP monthly).
      "series" => {
        "monthly" => v2["monthly"] || {},
        "annual" => v2["annual"] || {},
      },
      "provenance" => v2["provenance"] || [],
      "providers" => v2["providers"] || [],
    }
  end

  def parse_base_year(str)
    return { "base_period" => nil, "rebased_at" => nil } if str.nil? || str.empty?

    m = BASE_YEAR_RE.match(str.to_s)
    if m
      { "base_period" => m[:period], "rebased_at" => m[:rebased] }
    else
      warn "  WARN: unrecognised base_year #{str.inspect} — preserving as-is"
      { "base_period" => str.to_s, "rebased_at" => nil }
    end
  end

  # ---------- FX ----------

  def migrate_fx_files
    paths = Dir[File.join(DATA_ROOT, FX_USD_FILES)]
    stubs, real = paths.partition { |p| stub_file?(p) }

    consolidate_stubs_into_annual_fallback(stubs)

    real.each do |path|
      data = JSON.parse(File.read(path))
      next skip(path) if data["schema_version"] == 3

      v3 = build_fx_year_v3(data)
      write_json(path, v3)
      log "fx: rewrote #{File.basename(path)}"
    end
  end

  # A stub year file is one with empty `rates` and only an `annual` block.
  def stub_file?(path)
    data = JSON.parse(File.read(path))
    (data["rates"] || {}).empty? && (data["annual"] || {}).any?
  end

  def consolidate_stubs_into_annual_fallback(stub_paths)
    return if stub_paths.empty?

    annual_by_year = {}
    stub_paths.each do |path|
      data = JSON.parse(File.read(path))
      year = data["year"].to_s
      annual_by_year[year] = data["annual"]
    end

    out_path = File.join(DATA_ROOT, ANNUAL_FALLBACK_FILE)
    if File.exist?(out_path)
      prior = JSON.parse(File.read(out_path))
      (prior["annual"] || {}).each { |y, v| annual_by_year[y] ||= v }
    end

    # Provenance covers the contiguous year span.
    years_sorted = annual_by_year.keys.map(&:to_i).sort
    all_currencies = annual_by_year.values.flat_map(&:keys).uniq.sort

    v3 = {
      "schema_version" => 3,
      "base" => "USD",
      "annual" => annual_by_year,
      "provenance" => [
        {
          "series" => "annual",
          "currencies" => all_currencies,
          "from" => years_sorted.first.to_s,
          "to" => years_sorted.last.to_s,
          "provider" => "world_bank",
        },
      ],
      "providers" => [
        {
          "id" => "world_bank",
          "label" => "World Bank PA.NUS.FCRF",
          "fetched_at" => today,
          "status" => "ok",
        },
      ],
    }

    write_json(out_path, v3)
    log "fx: wrote #{ANNUAL_FALLBACK_FILE} (years #{years_sorted.first}..#{years_sorted.last}, " \
        "currencies #{all_currencies.join(",")})"

    # Sanity: every (year, currency) must round-trip before deleting stubs.
    stub_paths.each do |path|
      data = JSON.parse(File.read(path))
      year = data["year"].to_s
      (data["annual"] || {}).each do |ccy, rate|
        round = annual_by_year.dig(year, ccy)
        raise "stub consolidation lost #{year}/#{ccy} (#{rate})" if round.nil?
        raise "stub consolidation drifted #{year}/#{ccy}: #{rate} -> #{round}" if round != rate
      end
      File.delete(path)
      log "fx: deleted stub #{File.basename(path)}"
    end
  end

  def build_fx_year_v3(v2)
    rates = v2["rates"] || {}
    annual = v2["annual"] || {}

    provenance = []
    providers = []

    # Daily provenance from Frankfurter (ECB).
    if rates.any?
      dates_sorted = rates.keys.sort
      daily_currencies = rates.values.flat_map(&:keys).uniq.sort
      provenance << {
        "series" => "daily",
        "currencies" => daily_currencies,
        "from" => dates_sorted.first,
        "to" => dates_sorted.last,
        "provider" => "frankfurter",
      }
      providers << {
        "id" => "frankfurter",
        "label" => "Frankfurter (ECB) daily reference rates",
        "fetched_at" => today,
        "status" => "ok",
      }
    end

    # Annual provenance from World Bank (today only ever VND, but generalised).
    if annual.any?
      provenance << {
        "series" => "annual",
        "currencies" => annual.keys.sort,
        "year" => v2["year"],
        "provider" => "world_bank",
      }
      providers << {
        "id" => "world_bank",
        "label" => "World Bank PA.NUS.FCRF",
        "fetched_at" => today,
        "status" => "ok",
      }
    end

    out = {
      "schema_version" => 3,
      "base" => "USD",
      "year" => v2["year"],
      "rates" => rates,
      "provenance" => provenance,
      "providers" => providers,
    }
    out["annual"] = annual if annual.any?
    out
  end

  # ---------- Manifest ----------

  def write_manifest
    countries = Dir[File.join(DATA_ROOT, CPI_FILES)].map do |path|
      cpi = JSON.parse(File.read(path))
      code = cpi["country"]
      grans = []
      grans << "monthly" if (cpi.dig("series", "monthly") || {}).any?
      grans << "annual"  if (cpi.dig("series", "annual")  || {}).any?
      {
        "code" => code,
        "currency" => COUNTRY_TO_CURRENCY.fetch(code),
        "cpi_file" => "cpi/#{File.basename(path)}",
        "granularities" => grans,
      }
    end

    daily_years = Dir[File.join(DATA_ROOT, FX_USD_FILES)]
                  .map { |p| File.basename(p, ".json").to_i }
                  .sort

    all_fx_currencies = collect_fx_currencies(daily_years)

    manifest = {
      "schema_version" => 3,
      "generated_at" => today,
      "countries" => countries,
      "fx" => {
        "base" => "USD",
        "currencies" => all_fx_currencies,
        "daily_years" => daily_years,
        "annual_file" => ANNUAL_FALLBACK_FILE,
      },
    }

    write_json(File.join(DATA_ROOT, MANIFEST_FILE), manifest)
    log "manifest: wrote manifest.json (#{countries.size} countries, " \
        "#{daily_years.size} fx years)"
  end

  def collect_fx_currencies(years)
    seen = []
    years.each do |y|
      data = JSON.parse(File.read(File.join(DATA_ROOT, "fx", "usd", "#{y}.json")))
      (data["rates"] || {}).each_value { |day| seen.concat(day.keys) }
      seen.concat((data["annual"] || {}).keys)
    end
    annual_path = File.join(DATA_ROOT, ANNUAL_FALLBACK_FILE)
    if File.exist?(annual_path)
      data = JSON.parse(File.read(annual_path))
      (data["annual"] || {}).each_value { |yh| seen.concat(yh.keys) }
    end
    seen.uniq.sort
  end

  # ---------- Helpers ----------

  def write_json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{JSON.pretty_generate(deep_sort(data))}\n")
  end

  def deep_sort(obj)
    case obj
    when Hash
      obj.keys.map(&:to_s).sort.to_h { |k| [k, deep_sort(obj[k] || obj[k.to_sym])] }
    when Array
      obj.map { |v| deep_sort(v) }
    else
      obj
    end
  end

  def today
    Date.today.iso8601
  end

  def log(msg)
    puts msg
  end

  def skip(path)
    log "skip: #{File.basename(path)} already at schema_version 3"
  end
end
# rubocop:enable Metrics/ModuleLength

MigrateV2ToV3.run if __FILE__ == $PROGRAM_NAME
