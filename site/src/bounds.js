import { setText } from "./dom.js";
import { state } from "./state.js";
import { fromGemDate, toGemDate } from "./compute.js";
import { widestCpi } from "./lookups.js";

// Range-hint sync. Driven by form state and metadata — refreshRangeHint runs
// after readForm() and after metadata loads. With the smart-date text input,
// we no longer clamp min/max attributes on the input itself (the field is
// free-form); instead we surface bounds as a hint paragraph.
//
// The pure compute* helpers are split out so tests can exercise the bounds
// logic without a DOM round-trip. They derive what to bound from the form
// itself rather than a label: dates differ → CPI constrains; currencies
// differ → FX constrains; same on both → no narrowing.

// Year bounds for the binding constraint:
//   - dates differ → destination CPI window (inflation leg drives it)
//   - dates match, currencies differ → FX coverage
//   - same on both → no narrowing
export function computeYearBounds(form, countryByCurrency, fx) {
  const sameCurrency = form.fromCurrency === form.toCurrency;
  const sameDate = fromGemDate(form) === toGemDate(form);

  if (!sameDate) {
    const widest = widestCpi(countryByCurrency.get(form.toCurrency));
    if (widest) {
      return { min: widest.min.slice(0, 4), max: widest.max.slice(0, 4) };
    }
  }
  if (sameDate && !sameCurrency) {
    if (fx?.daily_min && fx?.daily_max) {
      return { min: fx.daily_min.slice(0, 4), max: fx.daily_max.slice(0, 4) };
    }
  }
  // Same currency + same date (or metadata not loaded yet): no narrowing.
  return null;
}

// Range hint reflects the binding constraint. The FX daily window starts on
// a specific weekday (1999-01-04). With the smart-date field, the precision
// the user types determines what they see — so we always show the year-grain
// hint; finer precision is implicit from the placeholder.
export function computeRangeHint(form, countryByCurrency, fx) {
  const sameCurrency = form.fromCurrency === form.toCurrency;
  const sameDate = fromGemDate(form) === toGemDate(form);

  if (sameCurrency && sameDate) {
    // Same currency, same date — nothing to convert, no coverage to hint at.
    return "";
  }
  if (sameDate && !sameCurrency) {
    if (!fx?.daily_min || !fx?.daily_max) return "";
    const min = fx.daily_min.slice(0, 4);
    const max = fx.daily_max.slice(0, 4);
    return `Daily FX: ${min}–${max} · annual fallback for earlier years`;
  }
  // Dates differ — destination CPI is the binding constraint, whether or
  // not currencies also differ.
  const c = countryByCurrency.get(form.toCurrency);
  const widest = widestCpi(c);
  if (!c || !widest) return "";
  return `${c.name} inflation data: ${widest.min.slice(0, 4)} – ${widest.max.slice(0, 4)}`;
}

export function refreshRangeHint() {
  const f = state.form;
  setText("#calc-range-hint", computeRangeHint(f, state.countryByCurrency, state.metadata?.fx));
}
