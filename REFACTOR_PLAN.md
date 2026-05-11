# Refactor Plan — timeprice 0.2.0 → 0.3.0

One branch (`refactor/0.3.0`), one PR, split into atomic commits so the reviewer can read commit-by-commit and `git bisect` works cleanly.

## Goal

Address the 12 findings from the architecture / Ruby / Sandi Metz review in a sequence that minimises rebase pain, lands wins early, and keeps each step independently revertible.

## Findings recap

**Blockers**
1. Duplicate `InflationResult#country_currency_label` shim at `cli.rb:313-321` silently shadows the canonical definition at `inflation.rb:21-24`.
2. Duplicate-branch rescue at `cli.rb:147-155` silenced via `.rubocop.yml` exclusion instead of being collapsed.
3. CLI owns currency metadata (`ZERO_DECIMAL_CURRENCIES`, `currency_decimals`, `round_money`) and re-implements `Point.coerce`'s shape rules.

**Suggestions**
4. `cli.rb` is 319 lines; commands parse + dispatch + format (Sandi Metz Rule 1 + 4).
5. `Compare.normalize_fx_date` owns date-granularity logic that belongs on `Point`.
6. `Point.coerce` is a textbook pattern-matching candidate.
7. `Supported.country_for_currency(...) || (raise ...)` reads as nil-pun.
8. `Inflation.lookup_index` is 28 lines; extract `CpiLookup` + `CpiPoint`.
9. `Sources::Coverage` should isolate filesystem I/O from the attribution registry.

**Nits**
10. Dead back-compat aliases (`CURRENCY_TO_COUNTRY`, `SUPPORTED_COUNTRIES`, `SUPPORTED_CURRENCIES`) in a 0.2.0 gem.
11. Adding a currency touches four places — collapse into a single `Supported::CURRENCY` table.
12. `DataLoader` defensive `||= {}` inside lookups; initialise once in `data_root=`.

---

## Branch: `refactor/0.3.0`

| # | Commit message | LOC | Notes |
|---|---|---|---|
| 1 | `fix: delete duplicate InflationResult#country_currency_label shim` | ~10 | Remove `cli.rb:313-321`. Add regression spec. |
| 2 | `fix: collapse duplicate-branch rescue in CLI` | ~5 | Single `rescue Timeprice::Error, ArgumentError => e`. Drop the RuboCop exclusion. |
| 3 | `refactor: consolidate currency metadata into Supported` | ~80 | New `Supported.decimals_for`; delete `ZERO_DECIMAL_CURRENCIES` + helpers from `cli.rb`. |
| 4 | `refactor: drop back-compat constant aliases` | ~10 del | `CURRENCY_TO_COUNTRY`, `SUPPORTED_COUNTRIES`, `SUPPORTED_CURRENCIES`. CHANGELOG entry. |
| 5 | `refactor: extract CLI presenters` | ~250 moved | New `lib/timeprice/cli/presenters/*.rb`. Each command → one collaborator. Golden snapshot must not change. |
| 6 | `refactor: add Point#fx_anchor_date, simplify Compare` | ~30 | Move date-granularity logic onto `Point`. |
| 7 | `refactor: pattern-match Point.coerce; CLI delegates parsing` | ~40 | `case/in`; `parse_compare_token` shrinks to a split + `Point.coerce`. |
| 8 | `refactor: extract CpiLookup from Inflation` | ~120 moved | `Inflation.adjust` becomes ~6 lines; `CpiPoint = Data.define(:value, :granularity)`. |
| 9 | `refactor: extract Sources::Coverage` | ~60 moved | `sources.rb` becomes the pure attribution registry. |
| 10 | `refactor: tidy DataLoader cache init and minor nits` | ~20 | Initialise caches in `data_root=`; explicit raise guards in `compare.rb:88-90`; `Errors::DataNotFound` cleanup. |
| 11 | `chore: 0.3.0 — refactor for clarity and Sandi Metz compliance` | — | Version bump + CHANGELOG. |

---

## Rules during the branch

- After every commit: `bundle exec rspec` green, `bundle exec rubocop` clean, golden snapshot unchanged (except where the commit explicitly justifies a change — none should).
- Commits are atomic. No "and also fixed X" trailers. If a commit must touch two areas to stay green, split it further.
- Use `git mv` for the presenter extraction so blame survives.
- Keep method bodies byte-identical during moves so git blame lands at the move commit, not on every line.

## Sequencing rationale

- **1 & 2 first** — one-line bug fixes, no design debate, close real defects.
- **3 before 5** — presenters need `Supported.decimals_for`.
- **4 bundled with 3** — same surface area; one CHANGELOG note.
- **6 before 7** — `Point#fx_anchor_date` is the API the simplified `Point.coerce` callers use.
- **8 & 9 last among refactors** — isolated, independently revertible if anything breaks.
- **10 last** — opportunistic tidying after the structural moves.

## Risk register

| Risk | Mitigation |
|------|-----------|
| Output drift breaks downstream users | Golden snapshot spec runs after every commit; output unchanged. |
| API surface change (aliases deleted) | Bundle into 0.3.0; one-line CHANGELOG note in commit 4 + 11. |
| Presenter extraction churns git blame | `git mv` + byte-identical method bodies during the move. |
| `Point.coerce` pattern-match regression | Property test over existing valid/invalid input fixtures; assert identical raise/return behaviour. |

## Out of scope

- Replacing string-keyed hashes from JSON with typed wrappers — nice-to-have, large diff, no current pain.
- A `bin/timeprice` integration test runner — golden snapshot already covers it.
- Adding new currencies/sources — orthogonal; commit 3 makes this cheaper *after* this PR lands.

## PR description outline

1. **Summary** — pointer to this file + top-3 blockers.
2. **Commit-by-commit walkthrough** — one line per commit explaining intent.
3. **Risk** — golden snapshot is the safety net; output unchanged.
4. **Out of scope** — typed JSON wrappers, new currencies/sources.

## Estimate

~8–12 hours focused work. Reviewer time ~30 minutes reading commit-by-commit.
