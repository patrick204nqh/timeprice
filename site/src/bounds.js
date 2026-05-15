import { $, setText } from "./dom.js";
import { state } from "./state.js";
import { deriveMode } from "./compute.js";
import { widestCpi } from "./lookups.js";

// Input min/max + range-hint sync. Driven by the form state and metadata —
// every refresh* call runs after readForm() and after metadata loads.
//
// The pure compute* helpers are split out so tests can exercise the bounds
// logic without a DOM round-trip; the refresh* wrappers just apply them.

// Year input bounds follow the destination currency's CPI window (the
// binding constraint when inflation is in play). In pure-FX mode CPI
// doesn't constrain anything — fall back to FX coverage so users can still
// pick a 2026 FX-only query even if the destination CPI ends in 2024.
// Identity mode skips narrowing (no compute happens), so we leave the union
// of CPI + FX bounds alone there.
export function computeYearBounds(form, mode, countryByCurrency, fx) {
  if (mode === "inflation" || mode === "compare") {
    const widest = widestCpi(countryByCurrency.get(form.toCurrency));
    if (widest) {
      return { min: widest.min.slice(0, 4), max: widest.max.slice(0, 4) };
    }
  }
  if (mode === "fx") {
    if (fx?.daily_min && fx?.daily_max) {
      return { min: fx.daily_min.slice(0, 4), max: fx.daily_max.slice(0, 4) };
    }
  }
  // identity mode (and metadata-not-yet-loaded fallback): no narrowing.
  return null;
}

export function refreshYearBounds() {
  const f = state.form;
  const mode = deriveMode(f);
  const fromEl = $("#from-year");
  const toEl = $("#to-year");
  if (!fromEl || !toEl) return;

  const bounds = computeYearBounds(f, mode, state.countryByCurrency, state.metadata?.fx);
  if (bounds) {
    fromEl.min = toEl.min = bounds.min;
    fromEl.max = toEl.max = bounds.max;
  }
}

// Day pickers in the "Use specific dates" disclosure must reflect whatever
// the active mode allows. FX/compare are limited by daily FX coverage;
// inflation is limited by the destination country's CPI window (which may
// extend before FX coverage starts).
export function refreshDateBounds() {
  const f = state.form;
  const mode = deriveMode(f);
  const fromEl = $("#from-date");
  const toEl = $("#to-date");
  if (!fromEl || !toEl) return;

  if (mode === "inflation" || mode === "identity") {
    const widest = widestCpi(state.countryByCurrency.get(f.toCurrency));
    if (widest) {
      // Monthly grain is "YYYY-MM"; promote to a YYYY-MM-DD bound.
      const min = widest.min.length === 7 ? `${widest.min}-01` : widest.min;
      const max = widest.max.length === 7 ? `${widest.max}-28` : widest.max;
      fromEl.min = toEl.min = min;
      fromEl.max = toEl.max = max;
      return;
    }
  }
  const fx = state.metadata?.fx;
  if (fx?.daily_min && fx?.daily_max) {
    fromEl.min = toEl.min = fx.daily_min;
    fromEl.max = toEl.max = fx.daily_max;
  }
}

// Range hint reflects the binding constraint for the active mode. The FX
// daily window starts on a specific weekday (1999-01-04), but day-of-month
// precision only matters to power users who've opened the precise-dates
// disclosure — year-only callers see year grain and a note about the
// annual fallback that covers earlier dates via the gem.
export function computeRangeHint(form, mode, countryByCurrency, fx, precise = false) {
  if (mode === "identity") {
    // Same currency, same date — nothing to convert, no coverage to hint at.
    return "";
  }
  if (mode === "fx") {
    if (!fx?.daily_min || !fx?.daily_max) return "";
    if (precise) {
      return `Daily FX: ${fx.daily_min} – ${fx.daily_max} · annual fallback for earlier years`;
    }
    const min = fx.daily_min.slice(0, 4);
    const max = fx.daily_max.slice(0, 4);
    return `Daily FX: ${min}–${max} · annual fallback for earlier years`;
  }
  const c = countryByCurrency.get(form.toCurrency);
  const widest = widestCpi(c);
  if (!c || !widest) return "";
  return `${c.name} inflation data: ${widest.min.slice(0, 4)} – ${widest.max.slice(0, 4)}`;
}

export function refreshRangeHint() {
  const f = state.form;
  const mode = deriveMode(f);
  const precise = !$("#precise-wrap")?.hidden;
  setText("#calc-range-hint", computeRangeHint(f, mode, state.countryByCurrency, state.metadata?.fx, precise));
}
