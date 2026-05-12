import { $, setText, fmtNumber } from "./dom.js";
import { state } from "./state.js";

const ZERO_DECIMAL = new Set(["JPY", "KRW", "VND"]);

function humanDate(iso) {
  if (!iso) return "";
  return new Intl.DateTimeFormat("en", {
    month: "short", day: "numeric", year: "numeric", timeZone: "UTC",
  }).format(new Date(iso));
}

// Resolve the FX date input. If the user expanded "Use specific date" and
// filled it in, that wins. Otherwise the year input is mapped to mid-year
// (June 15) — the gem walks backward to the nearest trading day, so
// mid-year is a safe, neutral default.
function resolveDate() {
  const dateEl = $("#fx-date");
  const wrap = $("#fx-date-wrap");
  if (wrap && !wrap.hidden && dateEl && dateEl.value) return dateEl.value;
  const year = $("#fx-year").value;
  return year ? `${year}-06-15` : "";
}

export function readFxForm() {
  state.fx = {
    amount: parseFloat($("#fx-amount").value) || 0,
    from: $("#fx-from").value,
    to: $("#fx-to").value,
    date: resolveDate(),
  };
}

function renderFxResult(r) {
  const decimals = ZERO_DECIMAL.has(r.to) ? 0 : 2;
  setText("#fx-amount-out", `${fmtNumber(r.amount, decimals)} ${r.to}`);
  const note = r.effective_date && r.effective_date !== r.date
    ? `rate on ${humanDate(r.effective_date)} (nearest trading day to ${humanDate(r.date)})`
    : `rate on ${humanDate(r.effective_date || r.date)}`;
  setText("#fx-meta", note);
}

function renderFxError(msg) {
  setText("#fx-amount-out", "—");
  setText("#fx-meta", msg);
}

export function runFx() {
  if (!state.vm) return;
  readFxForm();
  const { amount, from, to, date } = state.fx;

  if (from === to) {
    renderFxResult({ amount, to, date, effective_date: date, granularity: "identity" });
    return;
  }

  try {
    const rb = state.vm.eval(`
      require "timeprice"
      r = Timeprice.exchange(amount: ${amount}, from: "${from}", to: "${to}", date: "${date}")
      JSON.generate(r.to_h)
    `);
    renderFxResult(JSON.parse(rb.toString()));
  } catch (e) {
    console.error(e);
    const msg = (e && e.message || String(e)).split("\n")[0].replace(/^Error:\s*/, "");
    renderFxError(msg || "FX lookup failed.");
  }
}
