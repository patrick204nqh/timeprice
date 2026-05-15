import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm } from "./compute.js";

// URL hash format: #from=USD:1990&to=USD:2024&amount=100
// Dates may be YYYY, YYYY-MM, or YYYY-MM-DD — the smart-date field accepts
// any of the three. Empty side is allowed (renders an empty placeholder).
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

function applyPoint(spec, side) {
  const [currency, date] = spec.split(":");
  if (currency && $(`#${side}-currency`)) $(`#${side}-currency`).value = currency.toUpperCase();
  if (date !== undefined && $(`#${side}-when`)) $(`#${side}-when`).value = date;
}

export function writeUrl() {
  const f = state.form;
  const params = new URLSearchParams({
    from: `${f.fromCurrency}:${f.from}`,
    to:   `${f.toCurrency}:${f.to}`,
    amount: String(f.amount),
  });
  history.replaceState(null, "", `#${params.toString()}`);
}
