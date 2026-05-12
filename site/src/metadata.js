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

// Rebuild the currency dropdowns and date pickers from metadata, preserving
// any selection that's still valid.
//
// We only list currencies that pair with a country we ship CPI for — that's
// the set Timeprice.compare can handle as a destination (and the dropdown
// has no way to express "use this as source only"). Same constraint Compare
// itself enforces via UnsupportedCurrency.
export function applyMetadata() {
  if (!state.metadata) return;
  const { countries, currencies, fx, version, generated_at } = state.metadata;
  const calcCurrencies = currencies.filter((cur) =>
    countries.some((c) => c.currency === cur.code),
  );

  fillCurrencySelect("#from-currency", calcCurrencies);
  fillCurrencySelect("#to-currency", calcCurrencies);

  // Year inputs span the widest available CPI window so users can ask
  // century-old questions where data exists.
  const cpiMinYear = countries.reduce((acc, c) => {
    const grains = Object.values(c.cpi || {});
    const yrs = grains.map((g) => Number(g.min.slice(0, 4)));
    return Math.min(acc, ...yrs);
  }, 9999);
  const cpiMaxYear = countries.reduce((acc, c) => {
    const grains = Object.values(c.cpi || {});
    const yrs = grains.map((g) => Number(g.max.slice(0, 4)));
    return Math.max(acc, ...yrs);
  }, 0);
  if (cpiMinYear < 9999 && cpiMaxYear > 0) {
    for (const sel of ["#from-year", "#to-year"]) {
      const el = $(sel);
      if (el) { el.min = String(cpiMinYear); el.max = String(cpiMaxYear); }
    }
  }

  setText("#meta-version", `v${version}`);
  setText("#meta-refresh", generated_at);
  setText("#meta-refresh-2", generated_at);
  setText("#meta-country-count", String(countries.length));
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
