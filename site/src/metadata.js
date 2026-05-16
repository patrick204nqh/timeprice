import { $, setText } from "./dom.js";
import { state } from "./state.js";
import { widestCpi } from "./lookups.js";

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
  const { countries, currencies, version, generated_at } = state.metadata;
  state.countryByCode = new Map(countries.map((c) => [c.code, c]));
  state.countryByCurrency = new Map(countries.map((c) => [c.currency, c]));
  const calcCurrencies = currencies.filter((cur) => state.countryByCurrency.has(cur.code));

  fillCurrencySelect("#from-currency", calcCurrencies);
  fillCurrencySelect("#to-currency", calcCurrencies);

  // Year input bounds live in compute.js — they're per-currency and need
  // to update on every From/To-currency change, not just on metadata load.

  clampSeedToCpiWindow();

  setText("#meta-version", `v${version}`);
  setText("#meta-refresh", generated_at);
}

// CPI data lags reality by ~1–2 months, so the today-seed on `#to-when`
// can land past the destination country's latest CPI month. Clamp it
// down to the latest available month so first-paint doesn't fail with
// "no CPI data for <future-month>". Only touches the seed at metadata-
// load time — user-typed dates past the window still surface the normal
// validation error.
function clampSeedToCpiWindow() {
  const toEl = $("#to-when");
  if (!toEl?.value) return;
  const toCurrency = $("#to-currency")?.value;
  if (!toCurrency) return;
  const widest = widestCpi(state.countryByCurrency.get(toCurrency));
  if (!widest?.max) return;
  if (toEl.value > widest.max) {
    // Push through the widget when bound so the visible Y/M/D fields and the
    // grain badge update in lockstep with the hidden mirror. Falls back to a
    // raw value-set for tests that don't wire the widget.
    const widget = state.whenWidgets?.to;
    if (widget) widget.set(widest.max, { silent: true });
    else toEl.value = widest.max;
  }
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
