# Contributing to timeprice

Thanks for considering a contribution. This is a small project; the bar is
"does it ship correct, attributable, offline data and clean math?" — not
process compliance.

## Running tests

```bash
bundle install
bundle exec rspec                       # default suite (fixture + real-data goldens)
TIMEPRICE_REAL_DATA=1 bundle exec rspec  # also runs real-data smoke tests
```

CI runs against Ruby 3.4 (gem supports `>= 3.2`). Both `bundle exec rspec` and `bundle exec rubocop` must be green.

## Rules of the road

- **No runtime network calls.** Ever. The whole point of this gem is that
  `require "timeprice"` and the CLI work fully offline. Fetchers in
  `tools/data_pipeline/` run in CI only and write JSON to `data/` ahead of time.
- **Data PRs are normal PRs.** The monthly `chore(data): refresh ...` PR
  auto-merges if CI + golden snapshots pass and drift checks find no rebase.
  Anything else gets a human review.
- **Attribution is required.** Any new data source must come with its license
  added to `DATA_LICENSES.md`, an entry in `NOTICE`, an entry in
  `lib/timeprice/sources.rb`, and a clear attribution string.
- **Math regressions are the worst kind.** If you touch `Inflation`,
  `Exchange`, or `Compare`, the golden snapshot tests must still pass. Don't
  weaken them — add a new one for the case you care about.

## Proposing a new country or data source

Open an issue first using the `new_source.md` template. Include:

1. The source URL and license terms.
2. Frequency (monthly / annual), granularity, earliest date.
3. Whether the data needs an API key, and how reliable the publisher is.
4. The attribution string the publisher requires.

If the source is reasonable and the data fits the existing schema (see
`PLAN.md §2a`), the steps are:

1. Add a fetcher under `tools/data_pipeline/`.
2. Wire it into `tools/data_pipeline/runner.rb`.
3. Add the bundled JSON file under `data/` with a clean first pull.
4. Add a row to `DATA_LICENSES.md`, `NOTICE`, and `lib/timeprice/sources.rb`.
5. Add a golden snapshot test or two against a hand-checked value.

## Releasing

(Maintainer-only.) Bump `Timeprice::VERSION`, move `## [Unreleased]` to the
new version + today's date in `CHANGELOG.md`, commit, tag `vX.Y.Z`, push.
The release workflow handles the rest once it's wired up to RubyGems trusted
publishing.
