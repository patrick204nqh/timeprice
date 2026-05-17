import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm } from "./compute.js";
import { split as splitWhen } from "./when_input.js";

// URL hash format: #from=USD:1990&to=USD:2024&amount=100
// Dates may be YYYY, YYYY-MM, or YYYY-MM-DD — the smart-date field accepts
// any of the three. When a side has no date we write just the currency
// (e.g. `from=USD`) so a shared URL doesn't carry a trailing-colon stub,
// and so readUrl() doesn't clobber app.js's today-seed on the `to` side.
export function readUrl() {
  const h = location.hash.replace(/^#/, "");
  if (!h) return;
  const params = new URLSearchParams(h);
  const from = params.get("from");
  const to = params.get("to");
  const amount = params.get("amount");
  const forecast = params.get("forecast");
  if (amount) $("#calc-amount").value = amount;
  if (from) applyPoint(from, "from");
  if (to)   applyPoint(to, "to");
  if (forecast === "1" && $("#forecast-toggle")) {
    $("#forecast-toggle").checked = true;
  }
  readForm();
}

export function applyPoint(spec, side) {
  const [currency, date] = spec.split(":");
  if (currency && $(`#${side}-currency`)) $(`#${side}-currency`).value = currency.toUpperCase();
  // Empty date (`USD:` or `USD`) is treated as "no date" — leaves whatever
  // the field was seeded with intact (today, in the case of `to`).
  if (date) {
    // Prefer the bound widget so the visible Y/M/D inputs + grain badge stay
    // in sync. Falls back to writing the hidden mirror directly when the
    // widget isn't bound (unit tests that skip the wiring).
    const widget = state.whenWidgets?.[side];
    if (widget) {
      widget.set(date, { silent: true });
    } else {
      const hidden = $(`#${side}-when`);
      if (hidden) hidden.value = date;
      // Best-effort: if individual Y/M/D fields exist (test seeds them
      // explicitly), distribute the split there too.
      const parts = splitWhen(date);
      const yEl = $(`#${side}-year`);
      const mEl = $(`#${side}-month`);
      const dEl = $(`#${side}-day`);
      if (yEl) yEl.value = parts.year;
      if (mEl) mEl.value = parts.month;
      if (dEl) dEl.value = parts.day;
    }
  }
}

export function writeUrl() {
  const f = state.form;
  const entries = {
    from:   f.from ? `${f.fromCurrency}:${f.from}` : f.fromCurrency,
    to:     f.to   ? `${f.toCurrency}:${f.to}`     : f.toCurrency,
    amount: String(f.amount),
  };
  if (f.forecast) entries.forecast = "1";
  const params = new URLSearchParams(entries);
  history.replaceState(null, "", `#${params.toString()}`);
}
