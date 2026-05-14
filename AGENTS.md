# AGENTS.md

Guidance for AI coding agents working in this repo. Humans should read `README.md` first; this file repeats only the pieces agents need to act safely without re-deriving them.

## Project overview

`timeprice` is a Ruby gem that ships **offline** historical inflation (CPI) and FX data so callers can answer "what was 100 USD in 1990 worth in 2024 in VND?" with zero network calls and deterministic results. The same code is compiled to WebAssembly (`ruby.wasm`) and served from `site/` as a browser calculator — the gem and the site share one source of truth.

Two surfaces, one gem:

- **Gem** (`lib/`, `exe/`, `data/`, `spec/`) — the Ruby library + CLI + bundled dataset. Public API: `Timeprice.inflation`, `Timeprice.exchange`, `Timeprice.compare`, `Timeprice.metadata`, `Timeprice.sources`. All result objects are `Data.define` value objects.
- **Site** (`site/`) — a static single-page calculator that boots the gem in the browser via `ruby.wasm`. Built with Tailwind CSS. See `DESIGN.md` for the design system.

Data lives under `data/` in schema v3 (see `data/manifest.json` and `data/cpi/*.json` / `data/fx/usd/*.json`). A monthly GitHub Action refreshes it via `scripts/update_data.rb`.

## Setup commands

```bash
# Gem
bundle install
bundle exec rake spec        # tests
bundle exec rake rubocop     # lint
bundle exec rake             # both (default task)
bundle exec exe/timeprice --help

# Site
cd site
bun install                  # or npm install
bun run build                # produces site/public/tailwind.css and the wasm cache
# Serve site/ with any static server to test the calculator locally
```

Requires Ruby >= 3.2. The repo uses `lefthook` for pre-commit (RuboCop on staged Ruby files) and pre-push (RSpec + RuboCop). Do not bypass hooks (`--no-verify`) unless the user explicitly asks.

## Code style

- **Ruby**: enforced by RuboCop. `# frozen_string_literal: true` at the top of every `.rb` / `.rake` file. Two-space indent. Run `bundle exec rubocop -a` to auto-fix before committing.
- **Result objects** are `Data.define` — they support `.to_h`, `==`, and pattern matching. New public functions should return a `Data.define` value object, not a `Hash`, not an `OpenStruct`.
- **Errors** all inherit from `Timeprice::Error`. Do not raise bare `RuntimeError` or `ArgumentError` from public API surfaces; wrap in a `Timeprice::Error` subclass.
- **No Rails-isms.** This is plain Ruby. No `ActiveSupport`, no autoloading, no Railtie. `require "timeprice"` must work in a vanilla Ruby script.
- **Thread safety.** Data files are loaded once and cached as **frozen** hashes. Anything you cache from `data/` must be frozen before being assigned.
- **Site CSS**: Tailwind utility classes only. The design system is documented in `DESIGN.md` — match its tokens (stone palette, single emerald accent, mono for numerics, no shadows, no web fonts) when touching `site/index.html` or `site/src/`.
- **Comments**: default to none. Only add a comment when the *why* is non-obvious (a hidden constraint, a workaround, a counter-intuitive convention like the `compare` direction).

## Testing instructions

```bash
bundle exec rake spec                                  # full suite
bundle exec rspec spec/timeprice/inflation_spec.rb     # one file
bundle exec rspec spec/timeprice/inflation_spec.rb:42  # one example
bundle exec ruby scripts/check_schema_stability.rb     # data schema gate
```

- Specs live in `spec/` and use RSpec. Mirror the `lib/` tree.
- The data-schema check (`scripts/check_schema_stability.rb`) runs in CI and **must pass** for any PR that touches `data/` or the loader. If you change the schema, bump the version constant and update the check.
- Tests must not hit the network. Bundled fixtures and `data/` are the only sources of truth during specs.
- New countries / currencies / data ranges must be accompanied by specs covering at least the boundary years documented in the README coverage table.

## Compare semantics — non-negotiable

`Timeprice.compare(amount:, from:, to:)` follows one convention: **convert at the source date first, then inflate in the destination currency.** The alternative ("inflate first, then convert at the destination date") is mathematically wrong for high-inflation pairs because nominal FX already absorbs relative inflation. See the worked example in `README.md` ("Compare semantics — important").

Do not "fix" this convention unless the user explicitly asks for a behaviour change with a deliberate version bump. If a caller wants the naive direction, they can compose `inflation` + `exchange` themselves.

## Data changes

- **Adding a country / currency** is data work, not code work in most cases. Add the source files under `data/cpi/<country>.json` or `data/fx/usd/...`, update `data/manifest.json`, run `scripts/check_schema_stability.rb`, add specs, and update the coverage table in `README.md`.
- **Refreshing existing data** is automated by `scripts/update_data.rb` (run monthly by a GitHub Action). For ad-hoc refreshes set `TIMEPRICE_DATA_ROOT` to a working copy to test before committing.
- Every redistributed dataset has a license recorded in `DATA_LICENSES.md` and `NOTICE`. New sources require both files to be updated in the same PR.

## Site changes

- The design system is in `DESIGN.md` — read it before changing visual surfaces. Tokens are referenced as `{colors.x}` / `{component.y}`.
- Hard rules: warm `stone` neutral palette, **single emerald accent** reserved for the converted-amount span in the hero sentence only, **single amber state** for the Ruby-VM warm-up dot only, no drop shadows, no gradients, no web fonts, no icon libraries. Dark mode is first-class and applied pre-paint to avoid flash.
- Monospace + `tabular-nums` for every number, currency code, year, date, and version string. Prose stays in the system sans stack.
- The calc card has no submit button by design — the hero sentence updates live as inputs change.
- The `Timeprice.metadata` snapshot is the single source of truth for what the UI offers (currencies, years, ranges). Do not hardcode dropdown options in `site/index.html`; read them from metadata at boot.

## PR instructions

- Title format: `<area>: <imperative summary>` matching recent history (`site: …`, `docs: …`, `ci(pages): …`, `docs(site): …`). Keep it under 70 chars.
- One concern per PR. Data refresh PRs are separate from code PRs.
- Run `bundle exec rake` (spec + rubocop) before opening the PR. CI will re-run plus `check_schema_stability.rb`.
- If you touched the data schema, the design system, or the public API, call it out explicitly in the PR description — these are the load-bearing pieces.

## Safety / do-not-touch

- **Do not** introduce a network call into `lib/`. The whole point of the gem is offline determinism. Network access is allowed in `scripts/update_data.rb` (data refresh) and nowhere else.
- **Do not** add a runtime gem dependency casually. Each new dependency is a wasm-size tax on the browser build. Justify in the PR description.
- **Do not** flip the `compare` convention (see above).
- **Do not** add a second accent colour or any shadow/gradient/web-font to the site (see `DESIGN.md`).
- **Do not** ship a release commit. Releases are cut by the maintainer; agents stop at the PR.
- **Do not** `git push --force` to `main` or rewrite shared history.

## Where things are

| Path | What lives here |
|---|---|
| `lib/timeprice.rb` | Public API entry point — `inflation`, `exchange`, `compare`, `metadata`, `sources`. |
| `lib/timeprice/` | Internals — loader, calculators, value objects, errors. |
| `exe/timeprice` | CLI binary. |
| `data/manifest.json` | Authoritative list of supported countries/currencies/ranges. |
| `data/cpi/<country>.json` | One CPI series per country (monthly + annual). |
| `data/fx/usd/<year>.json` | Daily USD-base FX rates per year. |
| `data/fx/usd/_annual.json` | Annual-fallback FX rates (currently VND, RUB). |
| `scripts/update_data.rb` | Monthly data refresh — the only place that talks to the network. |
| `scripts/check_schema_stability.rb` | CI gate on data shape. |
| `spec/` | RSpec tests, mirroring `lib/`. |
| `site/` | Static browser calculator (Tailwind + ruby.wasm). |
| `site/index.html` | Single-page entry. |
| `site/src/app.js` | Calculator wiring (boot wasm, read metadata, update hero). |
| `DESIGN.md` | Site design system (token-referenced). |
| `DATA_LICENSES.md` | Per-source data licenses + attribution strings. |
| `PLAN.md` | Active roadmap / scratch — read for context, do not treat as spec. |
| `CHANGELOG.md` | Release log. Do not edit between releases unless asked. |
