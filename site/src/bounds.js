import { $, setText } from "./dom.js";
import { state } from "./state.js";
import { deriveMode } from "./compute.js";
import { widestCpi } from "./lookups.js";

// Input min/max + range-hint sync. Driven by the form state and metadata —
// every refresh* call runs after readForm() and after metadata loads.

// Year input bounds follow the destination currency's CPI window (the
// binding constraint when inflation is in play). When the form is in pure-FX
// mode (same year both sides), CPI doesn't constrain anything — fall back
// to FX coverage so users can still pick a 2026 FX-only query even if the
// destination CPI ends in 2024.
export function refreshYearBounds() {
  const f = state.form;
  const mode = deriveMode(f);
  const fromEl = $("#from-year");
  const toEl = $("#to-year");
  if (!fromEl || !toEl) return;

  let min, max;
  if (mode === "inflation" || mode === "compare" || mode === "identity") {
    const widest = widestCpi(state.countryByCurrency.get(f.toCurrency));
    if (widest) {
      min = widest.min.slice(0, 4);
      max = widest.max.slice(0, 4);
    }
  }
  if (!min || !max) {
    const fx = state.metadata?.fx;
    if (fx?.daily_min && fx?.daily_max) {
      min = fx.daily_min.slice(0, 4);
      max = fx.daily_max.slice(0, 4);
    }
  }
  if (min && max) {
    fromEl.min = toEl.min = min;
    fromEl.max = toEl.max = max;
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

// Range hint reflects the destination country's CPI window (the binding
// constraint when inflation is in play). Currency-only mode (same date) is
// FX-limited and gets its hint from FX coverage.
export function refreshRangeHint() {
  const f = state.form;
  const mode = deriveMode(f);
  if (mode === "fx" || mode === "identity") {
    const fx = state.metadata?.fx;
    if (fx?.daily_min && fx?.daily_max) {
      setText("#calc-range-hint", `FX coverage: ${fx.daily_min} – ${fx.daily_max}`);
    } else {
      setText("#calc-range-hint", "");
    }
    return;
  }
  const c = state.countryByCurrency.get(f.toCurrency);
  const widest = widestCpi(c);
  if (!c || !widest) { setText("#calc-range-hint", ""); return; }
  setText("#calc-range-hint", `${c.name} inflation data: ${widest.min.slice(0, 4)} – ${widest.max.slice(0, 4)}`);
}
