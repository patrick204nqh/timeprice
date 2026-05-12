import { currencyFor } from "./data.js";
import { setText, fmtNumber } from "./dom.js";

export function renderResult(result, country) {
  const cur = currencyFor(country);
  setText("#inf-amount-out", `${fmtNumber(result.amount)} ${cur}`);
  setText("#inf-detail", `${fmtNumber(result.original_amount)} ${cur} (${result.from}) → ${fmtNumber(result.amount)} ${cur} (${result.to})`);
  setText("#inf-meta", `CPI ${result.from_index} → ${result.to_index} · ${result.country} · ${result.granularity}`);
}

export function renderEmpty(message = "Press Calculate once the Ruby VM is ready.") {
  setText("#inf-amount-out", "—");
  setText("#inf-detail", message);
  setText("#inf-meta", "");
}

export function renderError(message) {
  setText("#inf-amount-out", "—");
  setText("#inf-detail", message);
  setText("#inf-meta", "");
}
