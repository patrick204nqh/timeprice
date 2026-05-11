# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
