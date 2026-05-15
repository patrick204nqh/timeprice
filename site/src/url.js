import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm } from "./compute.js";

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
  if (amount) $("#calc-amount").value = amount;
  if (from) applyPoint(from, "from");
  if (to)   applyPoint(to, "to");
  readForm();
}

export function applyPoint(spec, side) {
  const [currency, date] = spec.split(":");
  if (currency && $(`#${side}-currency`)) $(`#${side}-currency`).value = currency.toUpperCase();
  // Empty date (`USD:` or `USD`) is treated as "no date" — leaves whatever
  // the field was seeded with intact (today, in the case of `to`).
  if (date && $(`#${side}-when`)) $(`#${side}-when`).value = date;
}

export function writeUrl() {
  const f = state.form;
  const params = new URLSearchParams({
    from:   f.from ? `${f.fromCurrency}:${f.from}` : f.fromCurrency,
    to:     f.to   ? `${f.toCurrency}:${f.to}`     : f.toCurrency,
    amount: String(f.amount),
  });
  history.replaceState(null, "", `#${params.toString()}`);
}
