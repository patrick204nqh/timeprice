import { currencyFor } from "./data.js";
import { setText, fmtNumber } from "./dom.js";
import { state } from "./state.js";

function yearOf(month) {
  return (month || "").slice(0, 4);
}

function currencySymbol(cur) {
  return { USD: "$", GBP: "£", EUR: "€", JPY: "¥", VND: "₫" }[cur] || "";
}

// Update the big sentence in the hero. Pre-VM and during input we only know
// the "from" side; once the VM returns a result we fill in the "to" side too.
export function renderHero(result) {
  const { amount, from, country } = state.form;
  const cur = currencyFor(country);
  const sym = currencySymbol(cur);
  setText("#hero-from", `${sym}${fmtNumber(amount)} in ${yearOf(from)}`);
  if (result) {
    setText("#hero-to", `${sym}${fmtNumber(result.amount)} in ${yearOf(result.to)}`);
  } else {
    setText("#hero-to", `… in ${yearOf(state.form.to)}`);
  }
}

export function renderResult(result, country) {
  const cur = currencyFor(country);
  setText("#inf-amount-out", `${fmtNumber(result.amount)} ${cur}`);
  setText("#inf-detail", `${fmtNumber(result.original_amount)} ${cur} (${result.from}) → ${fmtNumber(result.amount)} ${cur} (${result.to})`);
  setText("#inf-meta", `CPI ${result.from_index} → ${result.to_index} · ${result.country} · ${result.granularity}`);
  renderHero(result);
}

export function renderEmpty(message = "Warming up Ruby VM…") {
  setText("#inf-amount-out", "—");
  setText("#inf-detail", message);
  setText("#inf-meta", "");
  renderHero(null);
}

export function renderError(message) {
  setText("#inf-amount-out", "—");
  setText("#inf-detail", message);
  setText("#inf-meta", "");
  renderHero(null);
}
