import { RANGES, RANGE_LABELS } from "./data.js";
import { $, setText } from "./dom.js";
import { state } from "./state.js";

export function readForm() {
  state.form = {
    amount: parseFloat($("#inf-amount").value) || 0,
    from:   $("#inf-from").value,
    to:     $("#inf-to").value,
    country: $("#inf-country").value,
  };
}

function clampMonth(value, country) {
  const r = RANGES[country];
  if (!r || !value) return value;
  if (value < r.min) return r.min;
  if (value > r.max) return r.max;
  return value;
}

export function applyRangeForCountry(country) {
  const r = RANGES[country];
  if (!r) return;
  for (const sel of ["#inf-from", "#inf-to"]) {
    const el = $(sel);
    el.min = r.min;
    el.max = r.max;
    const clamped = clampMonth(el.value, country);
    if (clamped !== el.value) el.value = clamped;
  }
  setText("#inf-range-hint", `Data available: ${RANGE_LABELS[country]}`);
}

export function validateRange(from, to, country) {
  const r = RANGES[country];
  if (!r) return null;
  const [minLabel, maxLabel] = RANGE_LABELS[country].split(" – ");
  if (from < r.min || to < r.min) return `${country} CPI data starts ${minLabel}.`;
  if (from > r.max || to > r.max) return `${country} CPI data ends ${maxLabel}.`;
  return null;
}
