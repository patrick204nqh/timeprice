import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm, compute } from "./compute.js";
import { renderSnippet, renderEmpty } from "./view.js";
import { refreshRangeHint } from "./bounds.js";
import { writeUrl } from "./url.js";

let calcTimer = null;
function scheduleCalc() {
  clearTimeout(calcTimer);
  calcTimer = setTimeout(compute, 120);
}

const INPUT_SELECTORS = [
  "#calc-amount",
  "#from-currency", "#from-when",
  "#to-currency",   "#to-when",
];

function onInput() {
  readForm();
  renderSnippet();
  // While the VM is still warming, repaint the "warming up" placeholder so
  // a fresh keystroke doesn't sit next to a now-stale empty-state message.
  // Once the VM is ready, leave the previous answer in place — scheduleCalc
  // repaints within 120ms.
  if (!state.vm) renderEmpty("Warming up Ruby VM…");
  refreshRangeHint();
  writeUrl();
  scheduleCalc();
}

export function bindCopyButtons() {
  document.body.addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-copy], #snip-copy, #copy-link");
    if (!btn) return;
    let text;
    if (btn.id === "copy-link") text = location.href;
    else if (btn.id === "snip-copy") text = $("#snippet").textContent;
    else text = btn.dataset.copy;
    try { await navigator.clipboard.writeText(text); } catch {}
    if (!btn.dataset.origText) btn.dataset.origText = btn.textContent;
    btn.textContent = "copied";
    setTimeout(() => { btn.textContent = btn.dataset.origText; }, 1200);
  });
}

export function bindCalcForm() {
  for (const sel of INPUT_SELECTORS) {
    const el = $(sel);
    if (!el) continue;
    el.addEventListener("input", onInput);
    el.addEventListener("change", onInput);
  }

  $("#forecast-toggle")?.addEventListener("change", () => {
    compute();
    writeUrl();
  });

  $("#calc-form").addEventListener("submit", (e) => {
    e.preventDefault();
    clearTimeout(calcTimer);
    compute();
  });
}

export function bindExampleChips() {
  const row = $("#example-chips");
  if (!row) return;
  row.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-example]");
    if (!btn) return;
    const [fromSpec, toSpec, amount] = btn.dataset.example.split("|");
    const [fromCur, fromDate] = fromSpec.split(":");
    const [toCur, toDate] = toSpec.split(":");
    $("#calc-amount").value = amount;
    $("#from-currency").value = fromCur;
    $("#to-currency").value = toCur;
    // Drive the Y/M/D widgets so the visible inputs + grain badge update.
    // Empty date == "blank the whole side" for chip clicks (different
    // contract from URL applyPoint, which preserves seeds on empty).
    state.whenWidgets?.from?.set(fromDate || "", { silent: true });
    state.whenWidgets?.to?.set(toDate || "", { silent: true });
    if (!state.whenWidgets) {
      // Fallback path for environments without widgets bound (tests).
      $("#from-when").value = fromDate || "";
      $("#to-when").value = toDate || "";
    }
    onInput();
  });
}
