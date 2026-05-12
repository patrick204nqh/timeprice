import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm } from "./compute.js";

// URL hash format: #from=USD:1990&to=USD:2024&amount=100
// Dates may be YYYY, YYYY-MM, or YYYY-MM-DD. The "precise" disclosure opens
// automatically when either side carries a month or day grain.
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
  if (needsPrecise(from) || needsPrecise(to)) openPrecise();
  readForm();
}

function applyPoint(spec, side) {
  const [currency, date] = spec.split(":");
  if (currency && $(`#${side}-currency`)) $(`#${side}-currency`).value = currency.toUpperCase();
  if (!date) return;
  if (/^\d{4}$/.test(date)) {
    $(`#${side}-year`).value = date;
  } else {
    // Month or day grain — populate both the year input and the day picker.
    $(`#${side}-year`).value = date.slice(0, 4);
    const dateEl = $(`#${side}-date`);
    if (dateEl) dateEl.value = /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : `${date}-15`;
  }
}

function needsPrecise(spec) {
  if (!spec) return false;
  const date = spec.split(":")[1] || "";
  return /^\d{4}-/.test(date);
}

function openPrecise() {
  const wrap = $("#precise-wrap");
  if (wrap) wrap.hidden = false;
  const label = $("#precise-toggle-label");
  const icon = $("#precise-toggle-icon");
  if (label) label.textContent = "Use year only";
  if (icon) icon.textContent = "▾";
}

export function writeUrl() {
  const f = state.form;
  const fromDate = f.fromDate || f.fromYear;
  const toDate = f.toDate || f.toYear;
  const params = new URLSearchParams({
    from: `${f.fromCurrency}:${fromDate}`,
    to:   `${f.toCurrency}:${toDate}`,
    amount: String(f.amount),
  });
  history.replaceState(null, "", `#${params.toString()}`);
}
