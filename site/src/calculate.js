import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm, validateRange } from "./form.js";
import { renderResult, renderError } from "./result.js";

function cleanErrorMessage(e) {
  const raw = (e && e.message) ? String(e.message) : String(e);
  const firstLine = raw.split("\n")[0].trim();
  return firstLine.replace(/^Error:\s*/, "") || "Calculation failed.";
}

export async function calculate() {
  if (!state.vm) return;
  readForm();
  const { amount, from, to, country } = state.form;

  const rangeErr = validateRange(from, to, country);
  if (rangeErr) {
    renderError(rangeErr);
    return;
  }

  const btn = $("#inf-calc");
  btn.disabled = true;
  const origLabel = btn.textContent;
  btn.textContent = "Calculating…";

  try {
    const rb = state.vm.eval(`
      require "timeprice"
      r = Timeprice.inflation(amount: ${amount}, from: "${from}", to: "${to}", country: "${country}")
      JSON.generate(r.to_h)
    `);
    const result = JSON.parse(rb.toString());
    renderResult(result, country);
  } catch (e) {
    console.error(e);
    renderError(cleanErrorMessage(e));
  } finally {
    btn.disabled = false;
    btn.textContent = origLabel;
  }
}
