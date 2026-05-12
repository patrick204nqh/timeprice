import { $, setText } from "./dom.js";
import { state } from "./state.js";
import { cpiMonthRange, rangeLabel } from "./metadata.js";

// Pre-VM fallback for the five countries listed in index.html. Replaced by
// metadata-derived ranges once the VM boots and Timeprice.metadata loads.
const FALLBACK_RANGES = {
  US: { min: "1990-01", max: "2026-03" },
  UK: { min: "1988-01", max: "2026-03" },
  EU: { min: "1996-01", max: "2025-12" },
  JP: { min: "1971-01", max: "2024-12" },
  VN: { min: "2001-12", max: "2026-03" },
};

function rangeFor(country) {
  return cpiMonthRange(country) || FALLBACK_RANGES[country] || null;
}

export function readForm() {
  state.form = {
    amount: parseFloat($("#inf-amount").value) || 0,
    from:   $("#inf-from").value,
    to:     $("#inf-to").value,
    country: $("#inf-country").value,
  };
}

function clampMonth(value, country) {
  const r = rangeFor(country);
  if (!r || !value) return value;
  if (value < r.min) return r.min;
  if (value > r.max) return r.max;
  return value;
}

export function applyRangeForCountry(country) {
  const r = rangeFor(country);
  if (!r) return;
  for (const sel of ["#inf-from", "#inf-to"]) {
    const el = $(sel);
    el.min = r.min;
    el.max = r.max;
    const clamped = clampMonth(el.value, country);
    if (clamped !== el.value) el.value = clamped;
  }
  setText("#inf-range-hint", `Data available: ${rangeLabel(country) || `${r.min} – ${r.max}`}`);
}

export function validateRange(from, to, country) {
  const r = rangeFor(country);
  if (!r) return null;
  const label = rangeLabel(country) || `${r.min} – ${r.max}`;
  const [minLabel, maxLabel] = label.split(" – ");
  if (from < r.min || to < r.min) return `${country} CPI data starts ${minLabel}.`;
  if (from > r.max || to > r.max) return `${country} CPI data ends ${maxLabel}.`;
  return null;
}
