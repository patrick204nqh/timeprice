import { $, setText } from "./dom.js";
import { state } from "./state.js";
import { deriveMode } from "./compute.js";
import { widestCpi } from "./lookups.js";

// Range-hint sync. Driven by form state and metadata — refreshRangeHint runs
// after readForm() and after metadata loads. With the smart-date text input,
// we no longer clamp min/max attributes on the input itself (the field is
// free-form); instead we surface bounds as a hint paragraph.
//
// The pure compute* helpers are split out so tests can exercise the bounds
// logic without a DOM round-trip.

// Year bounds for the destination currency's CPI window (the binding
// constraint when inflation is in play). In pure-FX mode CPI doesn't
// constrain anything — fall back to FX coverage. Identity mode skips
// narrowing.
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

// Range hint reflects the binding constraint for the active mode. The FX
// daily window starts on a specific weekday (1999-01-04). With the smart-
// date field, the precision the user types determines what they see — so
// we always show the year-grain hint; finer precision is implicit from the
// placeholder.
export function computeRangeHint(form, mode, countryByCurrency, fx) {
  if (mode === "identity") {
    // Same currency, same date — nothing to convert, no coverage to hint at.
    return "";
  }
  if (mode === "fx") {
    if (!fx?.daily_min || !fx?.daily_max) return "";
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
  setText("#calc-range-hint", computeRangeHint(f, mode, state.countryByCurrency, state.metadata?.fx));
}
