# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
