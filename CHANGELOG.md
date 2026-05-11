# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.5.0] - 2026-05-11

### Changed
- **Schema v2 → v3.** Breaking change to the bundled data contract. v0.4.x
  data files will not load on v0.5.0 and vice versa.
  - New top-level `data/manifest.json` — single source of truth for which
    countries and currencies the bundle supports. `Supported.countries` /
    `Supported.currencies` derive from it at runtime; the hardcoded Ruby
    constants `Supported::COUNTRIES` / `CURRENCIES` are gone.
  - CPI files use nested `series: { monthly, annual }` and a structured
    `index: { base_period, rebased_at }` block in place of the freeform
    `base_year` string. Top-level `source` and `updated_at` removed —
    `providers[]` is the source of truth for provenance.
  - FX year files now carry `provenance` + `providers` blocks, symmetric
    with CPI.
  - Pre-1999 stub year files (1983, 1986–1998) consolidated into
    `data/fx/_annual.json` for the sparse historical VND coverage. The
    daily-rate per-year files only exist for years with real daily data.
  - `Exchange.lookup_usd_base` adds a final fallback to `_annual.json`
    after the per-year `annual` block, tagged with `Granularity::ANNUAL`.

### Migration
- The bundled data ships in v3 — `gem install timeprice` is enough for
  most users.
- If you set `TIMEPRICE_DATA_ROOT` to a custom data tree, run
  `ruby scripts/migrate_v2_to_v3.rb` against it once. The script is
  idempotent and asserts every (year, currency) round-trips before
  deleting stub files.
- Custom callers that referenced `Supported::COUNTRIES` / `CURRENCIES`
  directly must switch to `Supported.countries` / `Supported.currencies`.

## [0.4.0] - 2026-05-11

### Changed
- **Schema v1 → v2.** Two structural data-layer changes, bundled under a
  single bump:
  - FX year files gain an optional top-level `annual` block. World Bank's
    annual VND/USD average is stored there exactly once per year instead of
    being broadcast across every daily date key. `Exchange.lookup_usd_base`
    falls back from daily to annual when no daily entry exists within ±7
    days and tags the result with `Granularity::ANNUAL`. `Compare` merges
    FX granularity with CPI granularity (worst-precision wins).
  - CPI provenance moves from a per-period map (`{"2025-01": "bls", ...}`)
    to a compact range list (`[{series, from, to, provider}, ...]`). Single
    -provider files (US/UK/EU/JP) collapse to 1–2 ranges; VN keeps the
    WB→IMF transition explicit. ~42 kb saved across the 5 CPI files; one
    real US data gap at 2025-10 is now visible instead of buried.
- `country_file.rb` rebase label now preserves the original base reference
  alongside the rebase date (e.g. `"2010=100 (rebased 2026-05-11)"`).

### Added
- Multi-source CPI chain for Vietnam: IMF Data Portal CPI dataflow
  (`api.imf.org`, SDMX 2.1) is the monthly primary; World Bank `FP.CPI.TOTL`
  remains as the annual fallback. The on-disk `data/cpi/vn.json` gains two
  additive fields — `provenance` (per-period source id) and `providers`
  (per-source status array) — so consumers can see which upstream supplied
  each datapoint. Schema version is unchanged; old readers ignore the new
  fields. Other country files (US, UK, EU, JP) gain the same fields on the
  next refresh.
- Internal: `Sources::Provider` / `Sources::CountryFile` / `Sources::MergePolicy`
  seam for layering multiple providers into a single country file with
  per-period provenance. Designed so future fresher sources (e.g. JP via
  e-Stat) can be added as one more entry without further plumbing.

## [0.3.0] - 2026-05-11

### Added
- `Timeprice::CpiLookup` and `Timeprice::CpiPoint` (Data.define of value +
  granularity). Owns all knowledge of the parsed CPI JSON shape so
  `Inflation.adjust` is a 6-line orchestration.
- `Timeprice::Sources::Coverage` — isolates runtime filesystem walking
  (FX year scan, JSON.parse of rate files) from the attribution registry.
- `Timeprice::Point#fx_anchor_date` — resolves a year / month / day `Point`
  to the day-resolved string FX lookup needs (mid-year for `YYYY`,
  mid-month for `YYYY-MM`).
- `Timeprice::Supported.decimals_for(currency)` — single source of truth
  for ISO 4217 minor-unit counts; non-CLI callers of `Timeprice.exchange`
  can now format results consistently.
- `Timeprice::CLI::Presenters::{Inflation, Exchange, Compare, Sources}` —
  each presenter exposes `#text_lines` and `#json_hash`; the CLI dispatches
  via a single `#render(presenter)` helper.

### Changed
- CLI output redesigned for readability: every `inflation`, `fx`, and `compare`
  command now leads with the answer on line 1 (e.g. `3,530,921 VND  in 2024`),
  followed by the calculation chain indented below. `head -1` extracts just
  the headline. Numbers are comma-grouped; JSON output is rounded to currency
  precision (no more `1861291.9999999998`).
- `timeprice sources` now renders as an aligned `ID / SOURCE / LICENSE /
  COVERAGE` table by default. Use `timeprice sources --verbose` (`-v`) for the
  previous detailed view with license URLs and full attribution.
- Top-level `timeprice help` rewritten — no more truncated descriptions; lists
  command names + descriptions, matching the `git` / `gh` / `cargo` convention.
- `Point.coerce` rewritten with pattern matching; the CLI's
  `parse_compare_token` now delegates to it instead of re-implementing
  the shape rules.
- `Compare.resolve_points` uses explicit `raise … unless` guards instead of
  `… || (raise …)` nil-pun.

### Removed
- Undocumented back-compat constants: `Timeprice::SUPPORTED_COUNTRIES`,
  `Timeprice::SUPPORTED_CURRENCIES`, and `Timeprice::Compare::CURRENCY_TO_COUNTRY`.
  Use `Supported::COUNTRIES`, `Supported::CURRENCIES`, and
  `Supported::CURRENCY_TO_COUNTRY` directly.
- `Lint/DuplicateBranch` RuboCop exclusion for `cli.rb` — the duplicate
  was collapsed into a single `rescue Timeprice::Error, ArgumentError`.

### Fixed
- Friendlier error messages: `Error: AMOUNT must be a number, got "abc"`
  instead of Ruby's raw `invalid value for Float(): "abc"`. Missing-options
  errors now say `missing required options: --from, --to` with a `See:
  timeprice help inflation` hint.

## [0.2.0] - 2026-05-11

### Added
- `Timeprice::Point` value object for compare inputs; `Point.coerce` accepts `Point` instances or 2-tuples in either `[currency, date]` or `[date, currency]` order.
- `Timeprice::Supported` module — canonical home for `COUNTRIES`, `CURRENCIES`, and the bidirectional currency↔country map. Replaces the duplicated maps in `Compare` and the CLI's `InflationResult` monkey-patch.
- `Sources::Base` class extracted from the CPI fetchers; `BLS`, `ONS`, and `Eurostat` now subclass it and implement only `fetch` returning `[monthly, annual]`. The drift-check, rebase, merge, write, and summary-log flow is shared.
- Per-fetcher GitHub Actions `::warning file=…,title=…::` annotations in `scripts/update_data.rb`, so individual fetcher failures show up on the workflow run with a link to the responsible source file.
- README "Using from Rails / Rake" section covering service objects, Sidekiq, Rake tasks, and `TIMEPRICE_DATA_ROOT`.
- YARD documentation on the public API (`Timeprice.{inflation,exchange,compare}`, `Inflation`, `Exchange`, `Compare`, `DataLoader`, `Sources`, error classes, `Supported`, `Point`).

### Changed
- `SUPPORTED_COUNTRIES` / `SUPPORTED_CURRENCIES` are now thin aliases for `Supported::COUNTRIES` / `Supported::CURRENCIES`; existing consumers keep working unchanged.
- `Compare::CURRENCY_TO_COUNTRY` is now an alias for `Supported::CURRENCY_TO_COUNTRY`.

## [0.1.2] - 2026-05-11

### Added
- RuboCop with `rubocop-rake` + `rubocop-rspec`, wired into Rake (`rake default` runs spec + rubocop) and CI (separate `RuboCop` job alongside `RSpec`).

### Changed
- `DataLoader.load_cpi` now distinguishes between "country isn't supported" (`UnsupportedCountry`) and "data file is missing on disk" (`DataNotFound` with the path the loader looked at). Previously both surfaced as `UnsupportedCountry`, masking install / `TIMEPRICE_DATA_ROOT` misconfigurations.
- `Timeprice.exchange` now rejects invalid calendar dates (e.g. `2021-02-29`) with `ArgumentError` instead of leaking a `Date::Error`. Honors the public error contract.
- Trimmed `ZERO_DECIMAL_CURRENCIES` to currencies actually supported by the gem (JPY, VND). Removed aspirational entries (KRW, IDR, HUF, CLP).
- Inline source comments now reference README sections (`README.md "Compare semantics"`) instead of `PLAN.md` (which is intentionally not shipped in the gem).
- `CONTRIBUTING.md` updated to match the single-Ruby CI; both `rspec` and `rubocop` must be green.



### Changed
- CLI output formatting: currency-aware decimals (no `.0000` on JPY/VND), magnitude-aware FX rate precision (no `91.180000` for a 91.18 rate).
- `granularity` is omitted from human output when it's `monthly` (the happy path); surfaced only when the result used annual data.
- Error messages hint at supported values: `Unsupported country: "FR" (supported: US, UK, EU, JP, VN)`; out-of-range CPI errors include the actual coverage range.
- Validate FX currencies against the supported list up front instead of failing with a generic "no FX rate" message.
- Tightened CLI command descriptions so `timeprice help` fits in a standard terminal.

### Fixed
- Hide Thor's built-in `tree` command — it was leaking into `timeprice help` as an internal-looking debug command.

## [0.1.0] - 2026-05-11

### Added
- Initial gem release.
- Library API: `Timeprice.inflation`, `Timeprice.exchange`, `Timeprice.compare`, returning `Data.define` value objects.
- CLI (`timeprice`): `inflation`, `fx`, `compare`, `sources`, `version`, all with `--json`.
- Bundled offline data for US, UK, Eurozone, Japan, Vietnam CPI and USD-base FX (EUR/GBP/JPY/VND).
- ECB reference rates via Frankfurter; VND via World Bank annual broadcast.
- Monthly GitHub Actions workflow that refreshes bundled data and opens a PR.
- Golden snapshot tests against real bundled data; property-style round-trip tests for inflation and FX.
- Attribution surfaces: `DATA_LICENSES.md`, `NOTICE`, `timeprice sources` CLI command.
