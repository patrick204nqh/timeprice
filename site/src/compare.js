import { $, setText, fmtNumber } from "./dom.js";
import { state } from "./state.js";

const ZERO_DECIMAL = new Set(["JPY", "KRW", "VND"]);

export function readCompareForm() {
  state.compare = {
    amount: parseFloat($("#cmp-amount").value) || 0,
    fromCurrency: $("#cmp-from-cur").value,
    fromYear: $("#cmp-from-year").value,
    toCurrency: $("#cmp-to-cur").value,
    toYear: $("#cmp-to-year").value,
  };
}

function renderCompareResult(r) {
  const toDec = ZERO_DECIMAL.has(r.to_currency) ? 0 : 2;
  const fromDec = ZERO_DECIMAL.has(r.from_currency) ? 0 : 2;
  setText("#cmp-amount-out", `${fmtNumber(r.amount, toDec)} ${r.to_currency}`);
  setText(
    "#cmp-meta",
    `${fmtNumber(r.original_amount, fromDec)} ${r.from_currency} (${r.from_date}) → ${fmtNumber(r.amount, toDec)} ${r.to_currency} (${r.to_date})`,
  );
}

function renderCompareError(msg) {
  setText("#cmp-amount-out", "—");
  setText("#cmp-meta", msg);
}

export function runCompare() {
  if (!state.vm) return;
  readCompareForm();
  const { amount, fromCurrency, fromYear, toCurrency, toYear } = state.compare;

  try {
    const rb = state.vm.eval(`
      require "timeprice"
      r = Timeprice.compare(
        amount: ${amount},
        from: ["${fromCurrency}", "${fromYear}"],
        to:   ["${toCurrency}", "${toYear}"],
      )
      JSON.generate(r.to_h)
    `);
    renderCompareResult(JSON.parse(rb.toString()));
  } catch (e) {
    console.error(e);
    const msg = (e && e.message || String(e)).split("\n")[0].replace(/^Error:\s*/, "");
    renderCompareError(msg || "Compare failed.");
  }
}
