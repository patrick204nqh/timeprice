# timeprice — site

The static site at `patrick204nqh.github.io/timeprice/` — a calculator that runs the actual
`timeprice` gem in the browser via [ruby.wasm](https://github.com/ruby/ruby.wasm).

## Local dev

```bash
./build.sh                      # build public/timeprice.wasm
python3 -m http.server 8000     # serve site/
open http://localhost:8000
```

`build.sh` packs the local gem (via `path: ".."` in the Gemfile) so the site always runs
the in-tree version, not a published release.

## Deploy

GitHub Actions builds and publishes on push to `main` when `lib/`, `data/`, `site/`,
or the workflow itself changes. See `.github/workflows/pages.yml`.

Enable Pages once in repo Settings → Pages → Source: **GitHub Actions**.

## Stack

- Static HTML, no JS framework, no bundler — Tailwind via Play CDN for v0.
- `@ruby/wasm-wasi@2` loaded from jsdelivr for the Ruby runtime.
- `rbwasm build` packs CRuby 3.3 + the gem + `data/` into a single `.wasm` (~13MB brotli).

## Scope (v0)

- Inflation tab end-to-end.
- FX and Compare tabs stubbed — the gem supports them; UI lands next.
- Static seed result so the page is interactive within ~500ms; wasm boot upgrades it to
  live in a few seconds.
- Share-by-URL state for Inflation (`#inflation/US/100/1990-01/2024-01`).
- `timeprice` ↔ `with API` snippet toggle.

## Why a static site instead of Vite

Faster to ship, zero JS toolchain to maintain, easy to read. If the page outgrows this
(more interactive features, design tokens, etc.) swap Tailwind Play CDN for a real
Tailwind build and add Vite — the wasm pipeline is independent and stays.
