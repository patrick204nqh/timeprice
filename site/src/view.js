import { $, setText, fmtNumber } from "./dom.js";
import { state } from "./state.js";
import { CURRENCY_SYMBOLS } from "./data.js";
import { countryFor, countryNameFor } from "./lookups.js";

// All DOM-as-output for the calculator. Inputs come from `state.form` and
// the optional `out` value returned by the VM. Nothing here reaches into
// the VM directly — that's compute.js's job.

const ZERO_DECIMAL = new Set(["JPY", "KRW", "VND"]);
const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function decimalsFor(currency) {
  return ZERO_DECIMAL.has(currency) ? 0 : 2;
}

function symbolFor(currency) {
  return CURRENCY_SYMBOLS[currency] || "";
}

function humanDate(iso) {
  if (!iso) return "";
  const [y, m, d] = iso.split("-");
  if (!m) return y;
  if (!d) return `${MONTH_NAMES[Number(m) - 1]} ${y}`;
  return `${MONTH_NAMES[Number(m) - 1]} ${Number(d)}, ${y}`;
}

function fromGemDate(f) { return f.fromDate || f.fromYear; }
function toGemDate(f)   { return f.toDate   || f.toYear;   }

function modeLabel(mode, f) {
  switch (mode) {
    case "inflation": return `Inflation — ${countryNameFor(f.toCurrency)}`;
    case "fx":        return "Exchange rate";
    case "compare":   return "Currency + inflation";
    default:          return "Same currency, same year";
  }
}

function metaLine(mode, r, f) {
  const destName = countryNameFor(f.toCurrency);
  switch (mode) {
    case "inflation":
      return `${destName} CPI · ${r.granularity || ""}`.replace(/ · $/, "");
    case "fx":
      return `Rate on ${humanDate(f.fromDate || `${f.fromYear}-06-15`)}`;
    case "compare":
      return `FX on ${humanDate(f.fromDate || `${f.fromYear}-06-15`)} · ${destName} CPI to ${humanDate(toGemDate(f))}`;
    default:
      return "No conversion needed";
  }
}

// Result-block state tint. DESIGN.md forbids new semantic colours, so error
// state shifts the surface from `surface-inset` to `surface-card` plus a 1px
// hairline — same elevation language as the calc card, repurposed to mark
// "this block is in a non-result state."
function setResultState(state_) {
  const el = $("#calc-result");
  if (!el) return;
  const errored = state_ === "error";
  el.classList.toggle("bg-stone-100", !errored);
  el.classList.toggle("dark:bg-stone-800/50", !errored);
  el.classList.toggle("bg-white", errored);
  el.classList.toggle("dark:bg-stone-900", errored);
  el.classList.toggle("border", errored);
  el.classList.toggle("border-stone-300", errored);
  el.classList.toggle("dark:border-stone-700", errored);
}

// Toggles hero typography between "live result" and "permanent error" looks.
// On error: drop the emerald accent + tabular-num cadence on hero-to and mute
// both halves to stone — em-dash + muted colour reads as "no value," whereas
// the default emerald + "…" reads as "still computing." Restored on success.
function setHeroErrorState(errored) {
  const from = $("#hero-from");
  const to = $("#hero-to");
  if (!from || !to) return;
  // hero-from: only the muted-stone tint differs in error state. The base
  // markup has no explicit colour, so adding/removing stone-500 is enough.
  from.classList.toggle("text-stone-500", errored);
  from.classList.toggle("dark:text-stone-400", errored);
  from.classList.toggle("tabular", !errored);
  // hero-to: swap emerald accent for muted stone and drop tabular cadence.
  to.classList.toggle("text-emerald-700", !errored);
  to.classList.toggle("dark:text-emerald-400", !errored);
  to.classList.toggle("tabular", !errored);
  to.classList.toggle("text-stone-500", errored);
  to.classList.toggle("dark:text-stone-400", errored);
}

// Disambiguate the source side in the hero whenever the two sides aren't
// the same currency — "$" alone reads as USD/AUD/CAD ambiguously, "$100 USD"
// doesn't. When source and dest dates match (FX mode), drop the trailing
// "in YYYY" on the right so the sentence doesn't double up.
// Updates only the "from" half of the hero. Used by error/empty paths so
// transient invalid input (a half-typed year, a paused keystroke) doesn't
// flash hero-to to "…" and back, which crosses the wrap threshold for
// large numbers and reads as a layout blink.
export function renderHeroFrom() {
  const f = state.form;
  const sym = symbolFor(f.fromCurrency);
  const fromDateStr = humanDate(fromGemDate(f));
  const showFromCode = f.fromCurrency !== f.toCurrency;
  const fromCode = showFromCode ? ` ${f.fromCurrency}` : "";
  setText("#hero-from", `${sym}${fmtNumber(f.amount, decimalsFor(f.fromCurrency))}${fromCode} in ${fromDateStr}`);
}

export function renderHero(out) {
  renderHeroFrom();
  const f = state.form;
  const showFromCode = f.fromCurrency !== f.toCurrency;
  if (out) {
    const toSym = symbolFor(out.to_currency || f.toCurrency);
    const toCode = showFromCode ? ` ${out.to_currency}` : "";
    const sameDate = out.from_date === out.to_date;
    const tail = sameDate ? "" : ` in ${humanDate(out.to_date)}`;
    setText("#hero-to", `${toSym}${fmtNumber(out.amount, decimalsFor(out.to_currency))}${toCode}${tail}`);
  } else {
    const sameDate = fromGemDate(f) === toGemDate(f);
    setText("#hero-to", sameDate ? "…" : `… in ${humanDate(toGemDate(f))}`);
  }
}

export function renderResult(out, mode) {
  const f = state.form;
  const dec = decimalsFor(out.to_currency);
  setResultState("ok");
  setHeroErrorState(false);
  setText("#calc-mode", modeLabel(mode, f));
  setText("#calc-amount-out", `${fmtNumber(out.amount, dec)} ${out.to_currency}`);
  setText(
    "#calc-detail",
    `${fmtNumber(out.original_amount, decimalsFor(out.from_currency))} ${out.from_currency} in ${humanDate(out.from_date)} → ${fmtNumber(out.amount, dec)} ${out.to_currency} in ${humanDate(out.to_date)}`,
  );
  setText("#calc-meta", metaLine(mode, out, f));
  renderHero(out);
  state.lastResultValid = true;
}

export function renderError(message) {
  state.lastResultValid = false;
  setResultState("error");
  setText("#calc-mode", "Error");
  setText("#calc-amount-out", "—");
  setText("#calc-detail", message);
  setText("#calc-meta", "");
  // Update only the "from" half, then plant a permanent em-dash on the
  // "to" side — leaving "…" there reads as "still computing," when in fact
  // we've given up. Em-dash + muted colour = "no value."
  renderHeroFrom();
  setText("#hero-to", "—");
  setHeroErrorState(true);
}

export function renderEmpty(message = "Warming up Ruby VM…") {
  setResultState("ok");
  setText("#calc-mode", "");
  setText("#calc-amount-out", "—");
  setText("#calc-detail", message);
  setText("#calc-meta", "");
  renderHero(null);
}

export function renderSnippet() {
  // If the current form would raise in Ruby, swap the snippet for a
  // comment. We keep the <details> affordance visible — disappearing UI is
  // less friendly than a placeholder that explains itself — but copying a
  // call that would raise is a footgun.
  if (!state.lastResultValid) {
    setText("#snippet", "# (form is currently invalid — fix the inputs above)");
    return;
  }
  const f = state.form;
  const fromDate = fromGemDate(f);
  const toDate = toGemDate(f);
  const sameCurrency = f.fromCurrency === f.toCurrency;
  const sameDate = fromDate === toDate;
  let body;
  if (sameCurrency && !sameDate) {
    body = `Timeprice.inflation(
  amount: ${f.amount},
  from:   "${fromDate}",
  to:     "${toDate}",
  country: "${countryFor(f.toCurrency)}",
).amount`;
  } else if (!sameCurrency && sameDate) {
    body = `Timeprice.exchange(
  amount: ${f.amount},
  from: "${f.fromCurrency}",
  to:   "${f.toCurrency}",
  date: "${f.fromDate || `${f.fromYear}-06-15`}",
).amount`;
  } else {
    body = `Timeprice.compare(
  amount: ${f.amount},
  from: ["${f.fromCurrency}", "${fromDate}"],
  to:   ["${f.toCurrency}", "${toDate}"],
).amount`;
  }
  setText("#snippet", `require "timeprice"\n\n${body}`);
}
