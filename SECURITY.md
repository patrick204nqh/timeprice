# Security policy

## Reporting a vulnerability

Email **patrick204nqh@gmail.com** with the details. Please don't open a public
issue for security reports.

I'll aim to acknowledge within **7 days** and have a fix or mitigation plan
within **30 days** for confirmed issues. This is a hobby project with no SLA,
but security reports jump the queue.

## Supported versions

Only the **latest released version** of the `timeprice` gem receives security
fixes. Pin to the current minor in your `Gemfile` and bump when a release goes
out. (See [`CHANGELOG.md`](CHANGELOG.md).)

## Scope

In scope:

- The `timeprice` gem itself (`lib/`, `exe/timeprice` CLI).
- Bundled data integrity — if you find a way to make the gem load tampered
  data from the bundled `data/` directory.
- The fetcher scripts under `scripts/sources/` that pull upstream data in CI.

Out of scope:

- Issues in upstream data providers (BLS, ONS, Eurostat, IMF, ECB, etc.) — those
  belong with the publisher.
- The live calculator at `patrick204nqh.github.io/timeprice` — it ships no
  user data anywhere and runs entirely client-side via ruby.wasm. Bug reports
  for the page itself are welcome via GitHub Issues, not as security reports.
- Denial-of-service from unbounded inputs to library functions — Ruby's normal
  resource limits apply; we don't promise constant-time behaviour.
