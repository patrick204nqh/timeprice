# Schema v3 migration plan

Target: `timeprice` v0.5.0. Breaking change to the bundled data contract — no
back-compat shim. v0.4.x data files will refuse to load on v0.5.0 and vice
versa.

## Motivation

Schema v2 left three asymmetries in the data layer:

1. **CPI files carry structured provenance; FX files carry a flat `source`
   string.** `timeprice sources` has to special-case FX.
2. **`Supported::COUNTRIES` / `CURRENCIES` are hardcoded in Ruby**, duplicating
   what is already discoverable from `data/`. Adding a country requires two
   edits and silently drifts if either is skipped.
3. **Pre-1990 FX year files (`1983`, `1986`–`1989`) are stubs** that advertise
   Frankfurter coverage they don't have. Five files, ~20 lines of metadata
   each, zero daily rates.

Schema v3 fixes all three by making the data files self-describing and
introducing a top-level manifest as the single source of truth for what is
bundled.

## Target shape

### `data/manifest.json` (new)

```json
{
  "schema_version": 3,
  "generated_at": "2026-05-11",
  "countries": [
    { "code": "US", "currency": "USD", "cpi_file": "cpi/us.json", "granularities": ["monthly", "annual"] },
    { "code": "UK", "currency": "GBP", "cpi_file": "cpi/uk.json", "granularities": ["monthly", "annual"] },
    { "code": "EU", "currency": "EUR", "cpi_file": "cpi/eu.json", "granularities": ["monthly", "annual"] },
    { "code": "JP", "currency": "JPY", "cpi_file": "cpi/jp.json", "granularities": ["annual"] },
    { "code": "VN", "currency": "VND", "cpi_file": "cpi/vn.json", "granularities": ["monthly", "annual"] }
  ],
  "fx": {
    "base": "USD",
    "currencies": ["EUR", "GBP", "JPY", "VND"],
    "daily_years": [1990, 1991, "...", 2026],
    "annual_file": "fx/_annual.json"
  }
}
```

### `data/cpi/{country}.json` (v3)

```json
{
  "schema_version": 3,
  "country": "VN",
  "index": {
    "base_period": "2010",
    "rebased_at": "2026-05-11"
  },
  "series": {
    "monthly": { "2001-12": 100.0, "2002-01": 100.4 },
    "annual":  { "1995": 22.4, "1996": 33.6 }
  },
  "provenance": [
    { "series": "monthly", "from": "2001-12", "to": "2026-03", "provider": "imf" },
    { "series": "annual",  "from": "1995",    "to": "2001",    "provider": "world_bank" },
    { "series": "annual",  "from": "2002",    "to": "2025",    "provider": "imf" }
  ],
  "providers": [
    { "id": "imf",        "label": "IMF Data Portal CPI dataflow",  "fetched_at": "2026-05-11", "status": "ok" },
    { "id": "world_bank", "label": "World Bank FP.CPI.TOTL",        "fetched_at": "2026-05-11", "status": "ok" }
  ]
}
```

Changes from v2:

- `monthly` / `annual` → nested under `series`.
- `base_year` (freeform string) → structured `index` object.
- Top-level `source` and `updated_at` **removed**. `providers[]` is the source
  of truth; `providers[].fetched_at` carries the per-provider refresh time.
- JP and any other annual-only country emit `series.monthly: {}` for uniform
  shape.

### `data/fx/usd/{year}.json` (v3) — only years with real daily data

```json
{
  "schema_version": 3,
  "base": "USD",
  "year": 2010,
  "rates": {
    "2010-01-04": { "EUR": 0.6942, "GBP": 0.6242, "JPY": 91.81 }
  },
  "annual": {
    "VND": 18612.92
  },
  "provenance": [
    { "series": "daily",  "currencies": ["EUR", "GBP", "JPY"], "from": "2010-01-04", "to": "2010-12-31", "provider": "frankfurter" },
    { "series": "annual", "currencies": ["VND"], "year": 2010, "provider": "world_bank" }
  ],
  "providers": [
    { "id": "frankfurter", "label": "Frankfurter (ECB) daily reference rates", "fetched_at": "2026-05-11", "status": "ok" },
    { "id": "world_bank",  "label": "World Bank PA.NUS.FCRF",                  "fetched_at": "2026-05-11", "status": "ok" }
  ]
}
```

### `data/fx/_annual.json` (new) — sparse historical annual-only coverage

Absorbs the five pre-1990 stub files (1983, 1986, 1987, 1988, 1989).

```json
{
  "schema_version": 3,
  "base": "USD",
  "annual": {
    "1983": { "VND": 1.0 },
    "1986": { "VND": 22.74 },
    "1987": { "VND": 78.29 },
    "1988": { "VND": 606.52 },
    "1989": { "VND": 4463.0 }
  },
  "provenance": [
    { "series": "annual", "currencies": ["VND"], "from": "1983", "to": "1989", "provider": "world_bank" }
  ],
  "providers": [
    { "id": "world_bank", "label": "World Bank PA.NUS.FCRF", "fetched_at": "2026-05-11", "status": "ok" }
  ]
}
```

Exchange-rate lookup order becomes: per-year `rates[date]` → per-year `annual[ccy]` → `_annual.json#annual[year][ccy]`. Each tier carries the appropriate `Granularity`.

---

## Phases

### Phase 0 — Pre-work

- [ ] Branch `feat/schema-v3`.
- [ ] Confirm `bundle exec rspec` green on `main`.
- [ ] Snapshot current golden values from `spec/golden/snapshot_spec.rb` to a scratch file — used as the baseline diff in Phase 4. Math must not drift; only file shape changes.

### Phase 1 — Schema doc

This file. Land first so Phases 2 and 3 reference one contract.

### Phase 2 — Data generators (the largest chunk)

Split into three commits for reviewability:

**2a. New shared writer `scripts/sources/fx_year_file.rb`.**
Mirrors `country_file.rb`. Owns one `data/fx/usd/{year}.json`. Accepts contributions of either `{daily: {date => {ccy => rate}}, provider_id:}` or `{annual: {ccy => rate}, provider_id:}`. Maintains `provenance` + `providers` blocks. Replaces the ad-hoc merging logic currently duplicated in `scripts/sources/frankfurter.rb#run` and `scripts/sources/world_bank.rb#run_vnd_fx`. The two existing scripts become thin orchestrators that call `FxYearFile#write_merged`.

**2b. v3 CPI shape in `scripts/sources/country_file.rb#write`.**

- Bump `schema_version` to `3`.
- Restructure: `monthly` / `annual` move under `"series"`.
- Replace `"base_year"` with structured `"index"` object. Parser:
  - `/\A(?<period>.+?)=100(?:\s*\(rebased\s+(?<rebased>\d{4}-\d{2}-\d{2})\))?\z/` matches the three known forms: `"1982-1984=100"`, `"2010=100"`, `"2010=100 (rebased 2026-05-11)"`.
  - On match: `{ "base_period": <period>, "rebased_at": <rebased or null> }`.
  - On no match: `{ "base_period": <original string>, "rebased_at": null }` (defensive fallback; log a warning).
- Drop top-level `"source"` and `"updated_at"`.

**2c. Manifest writer `scripts/sources/manifest.rb`.**

After all sources run, scans `data/cpi/*.json` + `data/fx/usd/*.json` + `data/fx/_annual.json`, emits `data/manifest.json`. Wired into `scripts/update_data.rb` as the final step. Idempotent and safe to re-run.

Phase 2 ends when `ruby scripts/update_data.rb` from a clean checkout produces v3-shaped files for every country and year, and `data/manifest.json` lists all five countries + four currencies.

### Phase 3 — One-time migration script `scripts/migrate_v2_to_v3.rb` (committed)

A standalone script (not a flag on the recurring updater) that:

1. Reads every v2 file under `data/`.
2. Round-trips it through the v3 writers from Phase 2.
3. Constructs `data/fx/_annual.json` from the five pre-1990 stubs.
4. Asserts every (year, currency) pair from the stubs is present in `_annual.json` before deleting them.
5. Writes `data/manifest.json`.

Kept in-tree because contributors with a custom `TIMEPRICE_DATA_ROOT` will need to run it once, and because the script is the most readable form of "what changed between v2 and v3" documentation.

### Phase 4 — Library reads v3

**`lib/timeprice/data_loader.rb`**

- `SUPPORTED_SCHEMA_VERSION = 3`.
- Add memoised `load_manifest` returning parsed `data/manifest.json`.
- Add `load_fx_annual_fallback` for `data/fx/_annual.json`.

**`lib/timeprice/supported.rb`** — delete hardcoded constants

- `COUNTRIES`, `CURRENCIES`, `COUNTRY_TO_CURRENCY`, `CURRENCY_TO_COUNTRY` become methods that read from the manifest. Memoised.
- `ZERO_DECIMAL_CURRENCIES` stays as a hardcoded constant (ISO 4217 metadata, not bundled data).
- Five internal call sites to update from `Supported::COUNTRIES` / `Supported::CURRENCIES` to method calls:
  - `lib/timeprice/errors.rb` (x2)
  - `lib/timeprice/data_loader.rb` (x1)
  - `lib/timeprice/exchange.rb` (x2)
- YARD `@param` / `@raise` doc references update with the same find/replace.

**`lib/timeprice/cpi_lookup.rb`** — two-line change:

```ruby
@monthly = data.dig("series", "monthly") || {}
@annual  = data.dig("series", "annual")  || {}
```

**`lib/timeprice/exchange.rb#lookup_usd_base`** — after the per-year annual fallback, add the final `_annual.json` fallback. Granularity tag is `Granularity::ANNUAL`.

**`lib/timeprice/sources/coverage.rb`** — simplify. Read `provenance[]` blocks directly instead of inferring coverage from data keys. One code path for CPI and FX.

Phase 4 ends when:

- `bundle exec ruby -Ilib -rtimeprice -e "puts Timeprice.inflation(amount: 100, from: '1990-01', to: '2024-01', country: 'US').amount"` returns a sensible number.
- `bundle exec exe/timeprice sources` runs cleanly.

### Phase 5 — Tests

- [ ] Regenerate `spec/golden/snapshot_spec.rb` goldens. **Manually diff against the Phase 0 baseline** — values must be byte-identical. Any drift is a bug.
- [ ] Update `spec/fixtures/cpi/*.json` + `spec/fixtures/fx/usd/*.json` to v3.
- [ ] Add `spec/fixtures/manifest.json` for tests that point `TIMEPRICE_DATA_ROOT` at fixtures.
- [ ] New tests:
  - `spec/timeprice/data_loader_spec.rb` — schema-version mismatch raises.
  - `spec/timeprice/supported_spec.rb` — supported set is derived from manifest. Test by pointing `TIMEPRICE_DATA_ROOT` at a 2-country fixture and asserting `Supported.countries.size == 2`.
  - `spec/timeprice/exchange_spec.rb` — `_annual.json` fallback hits for pre-1990 dates.
- `spec/scripts/sources/merge_policy_spec.rb` and `provenance_spec.rb` need **no changes** — their internal shapes are unaffected.

### Phase 6 — Schema stability guard

Update `scripts/check_schema_stability.rb` to assert:

- Every CPI file has `schema_version: 3`, `series`, `index`, `provenance`, `providers`.
- Every FX file has `schema_version: 3`, `provenance`, `providers`.
- `manifest.json` exists and references every CPI/FX file present.
- No orphan files under `data/` (every JSON is either referenced by manifest or is `manifest.json` / `fx/_annual.json` itself).

Wire into CI.

### Phase 7 — Release

- [ ] Bump `lib/timeprice/version.rb` to `0.5.0`.
- [ ] CHANGELOG entry with **explicit breaking-change banner**: "Schema bumped to v3. v0.4.x data files will not load. Re-install the gem to get v3-bundled data; if you set `TIMEPRICE_DATA_ROOT`, run `ruby scripts/migrate_v2_to_v3.rb` once against your data tree."
- [ ] Update README data-format section to reference this doc.
- [ ] Single PR. The schema change is atomic — reviewing it piecemeal hides whether the pieces fit together.

---

## Effort

~2 days focused work. Phase 2 and Phase 4 are the load-bearing chunks; the rest is mechanical. Phases 0, 1, 5b–7 are each < 30 min.

## Sequencing

Phases 2 and 4 could in theory run in parallel (generators write v3; library reads v3) but they are cheaper sequenced — Phase 2 produces real v3 files that Phase 4 develops against, instead of mocking the shape twice.

## Risk register

| Risk | Mitigation |
|------|------------|
| Golden value drift during regeneration | Phase 0 baseline + manual diff in Phase 5 |
| Pre-1990 VND data lost in `_annual.json` consolidation | `migrate_v2_to_v3.rb` asserts every (year, currency) round-trips before deleting stub files |
| Downstream users with custom `TIMEPRICE_DATA_ROOT` break silently | `UnsupportedSchemaVersion` raises loudly; CHANGELOG documents the migration script |
| `Supported::COUNTRIES` constant removal breaks an internal caller missed by grep | Five call sites identified; CI suite catches anything else |
| Partial `update_data.rb` run leaves a stale manifest | Fetchers are idempotent and re-runnable; manifest is written last after a clean run. Add a `data/manifest.json` write-via-atomic-rename to avoid half-written files. |

## Decisions baked into this plan

- **Version: 0.5.0.** Signals breaking schema change without claiming 1.0 stability yet.
- **Migration script committed**, not a one-shot. Doubles as v2→v3 delta documentation.
- **Top-level `source` and `updated_at` removed from CPI files.** `providers[]` is the source of truth.
- **Annual-only countries emit `series.monthly: {}`.** Uniform shape.
- **`ZERO_DECIMAL_CURRENCIES` stays hardcoded.** ISO 4217 metadata, not bundled data.
