import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm, compute, parseAmount } from "./compute.js";
import { renderSnippet, renderEmpty } from "./view.js";
import { refreshRangeHint } from "./bounds.js";
import { writeUrl } from "./url.js";
import * as affordance from "./affordance.js";

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

// Big amounts like "1000000" read better with thousands separators. The
// input is `type="text"` so we can drop a localized format in on every
// keystroke (live, with cursor preserved) and parse it back to a plain
// number in compute.js. Focus-time stripping is unnecessary — the input
// always carries the formatted form, and parseAmount is permissive.
function bindAmountInput() {
  const el = $("#calc-amount");
  if (!el) return;
  // Reformat on every input, preserving the caret position relative to the
  // digits typed so far (not the literal index, which jumps when a comma
  // appears or disappears).
  el.addEventListener("input", () => {
    const before = el.value;
    const caret  = el.selectionStart ?? before.length;
    const digitsBefore = before.slice(0, caret).replace(/[^0-9]/g, "").length;
    const formatted = formatAmount(before);
    if (formatted === before) return;
    el.value = formatted;
    const newCaret = caretForDigits(formatted, digitsBefore);
    try { el.setSelectionRange(newCaret, newCaret); } catch (_) {}
  });
  // Normalize whatever the input carries at boot (e.g. URL-restored "1000").
  el.value = formatAmount(el.value);
}

function formatAmount(raw) {
  const n = parseAmount(raw);
  // Preserve the trailing "." while the user is typing "1." → "1." (not "1").
  const trailingDot = /\.(\d*)$/.exec(String(raw));
  const decimals = trailingDot ? trailingDot[1].length : 0;
  // Strip thousands separators we already inserted but leave one decimal.
  if (!Number.isFinite(n)) return raw;
  const opts = decimals > 0
    ? { minimumFractionDigits: decimals, maximumFractionDigits: decimals }
    : { maximumFractionDigits: 0 };
  let out = n.toLocaleString(undefined, opts);
  // Honour an in-progress "." with no digits after it ("1.").
  if (trailingDot && trailingDot[1] === "" && !out.endsWith(".")) out += ".";
  return out;
}

function caretForDigits(formatted, n) {
  let seen = 0;
  for (let i = 0; i < formatted.length; i++) {
    if (/[0-9]/.test(formatted[i])) seen++;
    if (seen >= n) return i + 1;
  }
  return formatted.length;
}

export function bindCalcForm() {
  for (const sel of INPUT_SELECTORS) {
    const el = $(sel);
    if (!el) continue;
    el.addEventListener("input", onInput);
    el.addEventListener("change", onInput);
  }
  bindAmountInput();

  affordance.bind({ compute, writeUrl });

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
    $("#calc-amount").value = formatAmount(amount);
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
