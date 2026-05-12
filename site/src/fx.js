import { $, setText, fmtNumber } from "./dom.js";
import { state } from "./state.js";

const ZERO_DECIMAL = new Set(["JPY", "KRW", "VND"]);

export function readFxForm() {
  state.fx = {
    amount: parseFloat($("#fx-amount").value) || 0,
    from: $("#fx-from").value,
    to: $("#fx-to").value,
    date: $("#fx-date").value,
  };
}

function renderFxResult(r) {
  const decimals = ZERO_DECIMAL.has(r.to) ? 0 : 2;
  setText("#fx-amount-out", `${fmtNumber(r.amount, decimals)} ${r.to}`);
  const note = r.effective_date && r.effective_date !== r.date
    ? `rate on ${r.effective_date} (fallback from ${r.date}) · ${r.granularity}`
    : `rate on ${r.effective_date || r.date} · ${r.granularity}`;
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
