# timeprice

Offline historical inflation & FX for Ruby — bundled data, no API keys, monthly auto-refresh.

[![CI](https://github.com/patrick204nqh/timeprice/actions/workflows/ci.yml/badge.svg)](https://github.com/patrick204nqh/timeprice/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/timeprice.svg)](https://rubygems.org/gems/timeprice)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-ruby.svg)](https://www.ruby-lang.org/)

## Why this exists

Every other "historical inflation / FX" library wants you to wire up an API key, eat a rate
limit, and trust that someone else's server stays up forever. `timeprice` ships the data
in the gem. Once you `gem install timeprice`, you can answer "what was 100 USD in 1990
worth in 2024?" with zero network calls, deterministic results, and no surprise outages.
A monthly GitHub Action keeps the bundled data fresh; users just pin a gem version.

## Install

```bash
gem install timeprice
```

Or in a `Gemfile`:

```ruby
gem "timeprice", "~> 0.1"
```

Requires Ruby >= 3.2.

## CLI examples

```bash
$ timeprice inflation 100 --from 1990-01 --to 2024-01 --country US
242.09 USD  in 2024-01
  100.00 USD (1990-01) -> 242.09 USD (2024-01)
  US · monthly CPI

$ timeprice fx 100 USD JPY --date 2010-06-15
9,118 JPY  on 2010-06-15
  100.00 USD -> 9,118 JPY
  rate 91.18

$ timeprice compare 100 --from "2010 USD" --to "2024 VND"
3,530,921 VND  in 2024
  100.00 USD (2010)
    -> fx @ 18,612.92     -> 1,861,292 VND (2010)
    -> inflate x1.8970 VN -> 3,530,921 VND (2024, annual)
```

The first line of each result is the answer — pipe through `head -1` if a
script only needs the headline figure.

Every command supports `--json` for machine-readable output:

```bash
$ timeprice inflation 100 --from 1990-01 --to 2024-01 --country US --json
{"amount":242.08555729984302,"original_amount":100.0,"from":"1990-01","to":"2024-01","country":"US","from_index":127.4,"to_index":308.417,"granularity":"monthly"}
```

`timeprice sources` lists every bundled data source with its license, attribution string,
and current coverage range — derived dynamically from the bundled files.

## Library examples

```ruby
require "timeprice"

# Inflation adjustment
r = Timeprice.inflation(amount: 100, from: "1990-01", to: "2024-01", country: "US")
r.amount        # => 242.0855572998...
r.granularity   # => :monthly
r.to_h          # => { amount: ..., original_amount: ..., from: ..., country: ..., ... }

# Historical FX
r = Timeprice.exchange(amount: 100, from: "USD", to: "JPY", date: "2010-06-15")
r.amount         # => 9118.0
r.rate           # => 91.18
r.effective_date # => "2010-06-15" (or the nearest prior trading day on weekends/holidays)

# Combined: convert at source date, then inflate in destination currency
r = Timeprice.compare(amount: 100, from: ["USD", "2010"], to: ["VND", "2024"])
r.amount     # => 3530920.5840411717
r.fx_rate    # => 18612.92
r.cpi_ratio  # => 1.897026680414...
```

All result objects are `Data.define` value objects — they support `.to_h`, `==`, and
pattern matching, so you can hand them to JSON, RSpec, or `case/in` without ceremony.

## Supported countries, currencies, and data ranges

Coverage is derived from the bundled `data/` files. Re-check with `timeprice sources`.

| Country / Region | Currency | CPI source | Granularity | Coverage |
|------------------|----------|------------|-------------|----------|
| United States | USD | BLS CPI-U (`CUUR0000SA0`) | Monthly + annual | 1990-01 → present |
| United Kingdom | GBP | ONS CPI all-items (`D7BT`) | Monthly + annual | 1988-01 → present |
| Eurozone (EA) | EUR | Eurostat HICP (`prc_hicp_midx`) | Monthly + annual | 1996-01 → present |
| Japan | JPY | World Bank `FP.CPI.TOTL` (fallback) | Annual | 1960 → 2024 |
| Vietnam | VND | IMF Data Portal CPI dataflow (monthly primary) + World Bank `FP.CPI.TOTL` (annual fallback) | Monthly + annual | 1995 → present |

**FX (USD base):** ECB reference rates via Frankfurter for **EUR / GBP / JPY**, daily
1999 → present. **VND** uses the World Bank annual average (`PA.NUS.FCRF`), one value
per year, from 1983 → present. VND results are tagged `granularity: :annual` so callers
know they got the annual fallback rather than a daily rate.

Triangulated cross-rates (e.g. GBP → JPY) go through USD on the same effective date.
Weekend/holiday dates fall back up to 7 days to the nearest prior trading day.

## Compare semantics — important

This is the most important conceptual piece of the library, so it's worth reading.

`Timeprice.compare(amount:, from:, to:)` follows one specific convention:

> **Convert at the source date first, then inflate in the destination currency.**

Concretely, for `compare(amount: 100, from: ["USD", "2010"], to: ["VND", "2024"])`:

1. Convert 100 USD → VND at the **2010** FX rate (18,612.92), giving 1,861,292 VND.
2. Inflate that VND amount from 2010 → 2024 using **Vietnam's** CPI ratio
   (189.70 / 100.0 ≈ 1.897), giving **3,530,920.58 VND**.

### Why not the other direction?

The naive alternative ("inflate the 100 USD in US CPI to 2024, then convert at the 2024
FX rate") looks reasonable but is **wrong for any high-inflation pair**. Here's why:

Nominal FX rates already absorb relative inflation between the two currencies. If
Vietnam's CPI rises 90% over a period while US CPI rises 40%, the VND will tend to
weaken against the USD by roughly the inflation differential — that's already priced
into the 2024 USD→VND rate. So if you inflate the USD amount in US CPI **and then**
convert at a depreciated future VND rate, you double-count US inflation and produce a
number that overstates the equivalent purchasing power in Vietnam.

The convention used here — convert first, then inflate in the destination currency —
preserves **purchasing-power equivalence in the destination economy**. "100 USD in 2010
buys what 3,530,920 VND buys in 2024 in Vietnam."

### Worked example with numbers

Bundled data:
- USD→VND on 2010-06-30: `18612.92`
- VN CPI: 2010 = `100.0`, 2024 ≈ `189.70`
- US CPI: 2010-06 ≈ `217.97`, 2024 ≈ `308.42` (US ratio ≈ 1.415)
- USD→VND on 2024-06-30 (approx, broadcast annual): `~25,000`

| Approach | Calculation | Result |
|----------|-------------|--------|
| **timeprice (convert → inflate)** | 100 × 18,612.92 × 1.897 | **3,530,921 VND** |
| Naive (inflate → convert) | 100 × 1.415 × ~25,000 | ~3,537,500 VND |

These happen to land near each other for the USD/VND pair, but only because the FX
movement and inflation differential are roughly consistent here. For pairs where the
nominal rate has moved **out of step** with inflation (currency crises, pegs, controls),
the two approaches diverge by tens of percent. The "convert then inflate" answer is the
one that meaningfully tracks purchasing power.

If you specifically want the mechanical "inflate then convert" answer for some reason,
do it yourself — it's two library calls:

```ruby
inflated = Timeprice.inflation(amount: 100, from: "2010", to: "2024", country: "US").amount
converted = Timeprice.exchange(amount: inflated, from: "USD", to: "VND", date: "2024-06-30").amount
```

## Using from Rails / Rake

`timeprice` is a plain Ruby library — no Railtie, no engine, no autoload magic. It works
the same way as `BigDecimal` or `JSON`: require it once, call the module functions.

### In a Rails app

Add the gem to your `Gemfile`:

```ruby
gem "timeprice", "~> 0.1"
```

Then call it directly from controllers, jobs, presenters, or service objects. The library
is thread-safe (data files are loaded once and cached as frozen hashes), so it's safe to
call from threaded servers (Puma) and Sidekiq workers:

```ruby
# app/services/historical_price.rb
class HistoricalPrice
  def self.in_today_dollars(amount, year)
    Timeprice.inflation(
      amount: amount,
      from: year.to_s,
      to: Date.current.strftime("%Y-%m"),
      country: "US"
    ).amount
  end
end
```

Errors all inherit from `Timeprice::Error`, so a single rescue covers everything:

```ruby
rescue Timeprice::Error => e
  Rails.logger.warn("timeprice lookup failed: #{e.message}")
  nil
end
```

Result objects respond to `#to_h`, so they serialize cleanly in JSON APIs:

```ruby
def show
  render json: Timeprice.exchange(amount: 100, from: "USD", to: "EUR", date: params[:date]).to_h
end
```

### In a Rake task

```ruby
# lib/tasks/inflation.rake
require "timeprice"

namespace :inflation do
  desc "Print 1990→today inflation for the supported countries"
  task :report do
    today = Date.today.strftime("%Y-%m")
    %w[US UK EU JP VN].each do |c|
      r = Timeprice.inflation(amount: 100, from: "1990", to: today, country: c)
      puts "#{c}: 100 in 1990 → #{r.amount.round(2)} in #{today} (#{r.granularity})"
    end
  end
end
```

### Configuring the data root

By default the gem reads from its bundled `data/` directory. To point at a different
checkout (useful for testing a new data refresh before releasing it), set
`TIMEPRICE_DATA_ROOT`:

```bash
TIMEPRICE_DATA_ROOT=/path/to/timeprice/data bundle exec rake inflation:report
```

Or programmatically:

```ruby
Timeprice::DataLoader.data_root = "/path/to/timeprice/data"
```

Reassigning `data_root` clears the in-memory cache, so it's safe to call between requests
in development.

## Data sources & attribution

`timeprice` redistributes data from several public sources. Each is governed by its own
license — see `DATA_LICENSES.md` and `NOTICE` for the full table and license URLs.

- **U.S. CPI:** Data: U.S. Bureau of Labor Statistics (public domain).
- **UK CPI:** Contains public sector information licensed under the Open Government Licence v3.0.
- **Eurozone HICP:** Source: Eurostat (reuse permitted with attribution).
- **Japan CPI (fallback):** Source: World Bank, FP.CPI.TOTL (CC BY 4.0).
- **Vietnam CPI:** Sources: IMF Data Portal CPI dataflow (monthly primary); World Bank, FP.CPI.TOTL (annual fallback, CC BY 4.0).
- **FX rates:** European Central Bank reference rates via Frankfurter.
- **VND FX (annual broadcast):** World Bank, PA.NUS.FCRF (CC BY 4.0).

If you redistribute results derived from this gem, reproduce the relevant attribution
strings. `timeprice sources` prints them in plain text and as JSON.

## Data format

Bundled data lives under `data/` in schema v3 and is self-describing:

- `data/manifest.json` — the supported set (countries, currencies, FX years).
- `data/cpi/<country>.json` — CPI for one country: `series.{monthly,annual}`,
  structured `index` block, `provenance` ranges, `providers` attribution.
- `data/fx/usd/<year>.json` — daily USD-base FX rates for one year (one file
  per year, EUR/GBP/JPY).
- `data/fx/usd/_annual.json` — annual USD-base FX rates across all years for
  currencies sourced at annual resolution (today only VND). Used as the
  fallback tier when no daily rate covers the requested date.

`scripts/check_schema_stability.rb` enforces the shape in CI.

## Author

Built by [Patrick](https://github.com/patrick204nqh).

---

This is a maintained-on-best-effort open source project. Bug reports and
data-correctness issues are welcome; new-country requests will be evaluated
case-by-case based on source availability and maintainer bandwidth. No SLA.

## License

Code: MIT (see `LICENSE.txt`). Data: see `DATA_LICENSES.md` — each upstream source
retains its own license.
