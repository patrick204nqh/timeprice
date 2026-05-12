import { $, setText } from "./dom.js";
import { state } from "./state.js";

// Pull Timeprice.metadata out of the VM and cache on state.metadata.
// Returns true on success, false if the VM doesn't expose metadata (older
// wasm) — in which case the pre-VM hardcoded lists stay in place.
export function loadMetadata() {
  if (!state.vm) return false;
  try {
    const rb = state.vm.eval(`
      require "timeprice"
      JSON.generate(Timeprice.metadata)
    `);
    state.metadata = JSON.parse(rb.toString());
    return true;
  } catch (e) {
    console.warn("Timeprice.metadata unavailable — keeping pre-VM defaults.", e);
    return false;
  }
}

// Range used by the month picker. Prefers monthly, then quarterly (rendered as
// a YYYY-MM month boundary), then annual.
export function cpiMonthRange(country) {
  const c = state.metadata?.countries?.find((x) => x.code === country);
  if (!c) return null;
  const monthly = c.cpi.monthly;
  if (monthly) return { min: monthly.min, max: monthly.max };
  const quarterly = c.cpi.quarterly;
  if (quarterly) return { min: quarterlyToMonth(quarterly.min, "start"), max: quarterlyToMonth(quarterly.max, "end") };
  const annual = c.cpi.annual;
  if (annual) return { min: `${annual.min}-01`, max: `${annual.max}-12` };
  return null;
}

function quarterlyToMonth(qkey, edge) {
  // "2026-Q1" → "2026-01" (start) or "2026-03" (end)
  const [year, q] = qkey.split("-Q");
  const startMonth = (Number(q) - 1) * 3 + 1;
  const month = edge === "end" ? startMonth + 2 : startMonth;
  return `${year}-${String(month).padStart(2, "0")}`;
}

export function rangeLabel(country) {
  const r = cpiMonthRange(country);
  if (!r) return "";
  return `${humanMonth(r.min)} – ${humanMonth(r.max)}`;
}

function humanMonth(ym) {
  if (!ym) return "";
  const [y, m] = ym.split("-");
  const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${names[Number(m) - 1]} ${y}`;
}

// Rebuild the dropdowns and date pickers from metadata, preserving any
// selection that's still valid.
export function applyMetadata() {
  if (!state.metadata) return;
  const { countries, currencies, fx, version, generated_at } = state.metadata;

  fillCountrySelect("#inf-country", countries);

  // Currencies — FX from/to use all, Compare uses currencies whose country
  // ships CPI (so the inflation step has a series to use).
  fillCurrencySelect("#fx-from", currencies);
  fillCurrencySelect("#fx-to", currencies);
  const compareCurrencies = currencies.filter((cur) =>
    countries.some((c) => c.currency === cur.code),
  );
  fillCurrencySelect("#cmp-from-cur", compareCurrencies);
  fillCurrencySelect("#cmp-to-cur", compareCurrencies);

  // Date picker bounds from FX coverage.
  const fxDate = $("#fx-date");
  if (fxDate && fx.daily_min && fx.daily_max) {
    fxDate.min = fx.daily_min;
    fxDate.max = fx.daily_max;
  }

  // Compare year inputs span FX coverage (broadest sensible default).
  const fxMinYear = fx.daily_min?.slice(0, 4);
  const fxMaxYear = fx.daily_max?.slice(0, 4);
  for (const sel of ["#cmp-from-year", "#cmp-to-year"]) {
    const el = $(sel);
    if (el && fxMinYear && fxMaxYear) {
      el.min = fxMinYear;
      el.max = fxMaxYear;
    }
  }

  // Hero refresh date + version pill.
  setText("#meta-version", `v${version}`);
  setText("#meta-refresh", generated_at);
  setText("#meta-refresh-2", generated_at);
}

function fillCountrySelect(sel, countries) {
  const el = $(sel);
  if (!el) return;
  const prev = el.value;
  el.innerHTML = "";
  for (const c of countries) {
    const opt = document.createElement("option");
    opt.value = c.code;
    opt.textContent = `${c.code} — ${c.name} (${c.currency})`;
    el.appendChild(opt);
  }
  if (countries.some((c) => c.code === prev)) el.value = prev;
}

function fillCurrencySelect(sel, currencies) {
  const el = $(sel);
  if (!el) return;
  const prev = el.value;
  el.innerHTML = "";
  for (const c of currencies) {
    const opt = document.createElement("option");
    opt.value = c.code;
    opt.textContent = `${c.code} — ${c.name}`;
    el.appendChild(opt);
  }
  if (currencies.some((c) => c.code === prev)) el.value = prev;
}
