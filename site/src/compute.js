import { $ } from "./dom.js";
import { state } from "./state.js";
import { widestCpi, countryNameFor } from "./lookups.js";
import { renderResult, renderError, renderEmpty } from "./view.js";

// Form reading, mode derivation, validation, and the VM call. Rendering is
// in view.js; input min/max sync is in bounds.js. This module owns the
// orchestration path: form → validate → VM eval → render.

// Smart-date inputs accept YYYY, YYYY-MM, or YYYY-MM-DD. The gem accepts
// the same three precisions verbatim, so we trim whitespace and pass them
// through unchanged.
export const DATE_SHAPE = /^\d{4}(-\d{2}(-\d{2})?)?$/;

export function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

// Read the calculator form. Both date fields are free-form text; the gem
// infers granularity from the input precision. An empty `to` defaults to
// today; an empty `from` is kept empty so compute() can short-circuit.
export function readForm() {
  const fromRaw = ($("#from-when")?.value || "").trim();
  const toRaw = ($("#to-when")?.value || "").trim();
  state.form = {
    amount: parseFloat($("#calc-amount").value) || 0,
    fromCurrency: $("#from-currency").value,
    from: fromRaw,
    toCurrency: $("#to-currency").value,
    to: toRaw,
  };
}

// What the gem actually sees. `to` defaults to today when blank.
function fromGemDate(f) { return f.from; }
function toGemDate(f)   { return f.to || todayIso(); }

// Mode is self-derived. Same currency, different date → inflation.
// Same date, different currency → FX. Different on both axes → compare.
export function deriveMode(f) {
  const sameCurrency = f.fromCurrency === f.toCurrency;
  const sameDate = fromGemDate(f) === toGemDate(f);
  if (sameCurrency && sameDate) return "identity";
  if (sameCurrency) return "inflation";
  if (sameDate) return "fx";
  return "compare";
}

// Translate gem error messages into something a civilian can act on. The
// gem's defaults are technically accurate but full of jargon — "Date "1850"
// out of supported range" tells the user what's wrong without telling them
// what to do about it.
export function humaniseError(raw) {
  const first = raw.split("\n")[0].replace(/^Error:\s*/, "").trim();

  // Date "1850" out of supported range "1990-01".."2026-03"
  const oor = first.match(/Date\s+"([^"]+)"\s+out of supported range\s+"([^"]+)"\.\."([^"]+)"/i);
  if (oor) {
    const minYear = oor[2].slice(0, 4);
    const maxYear = oor[3].slice(0, 4);
    return `That date is outside our data range. Try a year between ${minYear} and ${maxYear}.`;
  }

  if (/Unsupported currency/i.test(first)) {
    return "That currency isn't in our dataset — pick one from the dropdown.";
  }
  if (/Unsupported country/i.test(first)) {
    return "That country isn't in our dataset — pick one from the dropdown.";
  }
  if (/Data not found|No FX data|DataNotFound|triangulation date mismatch|No FX rate/i.test(first)) {
    return "No data point for that combination. Try a nearby year.";
  }
  return first || "Calculation failed.";
}

// Pre-VM validation. Catches the obvious "wrong year" mistakes without
// round-tripping through the VM — and lets us reference the destination
// country by name when explaining the bound.
export function validateForm(f, mode) {
  const fromYear = Number(fromGemDate(f).slice(0, 4));
  const toYear   = Number(toGemDate(f).slice(0, 4));
  if (!fromYear || !toYear) return null;

  if (mode === "inflation" || mode === "compare") {
    const widest = widestCpi(state.countryByCurrency.get(f.toCurrency));
    if (widest) {
      const min = Number(widest.min.slice(0, 4));
      const max = Number(widest.max.slice(0, 4));
      const cName = countryNameFor(f.toCurrency);
      if (toYear < min || fromYear < min) {
        return `${cName} inflation data starts ${min}. Pick a year from ${min} on.`;
      }
      if (toYear > max || fromYear > max) {
        return `${cName} inflation data ends ${max}. Pick a year up to ${max}.`;
      }
    }
  }

  if (mode === "fx" || mode === "compare") {
    const fx = state.metadata?.fx;
    if (fx?.daily_min && fx?.daily_max) {
      const min = Number(fx.daily_min.slice(0, 4));
      const max = Number(fx.daily_max.slice(0, 4));
      // FX rate is sampled at the source date (Compare's convention too).
      if (fromYear < min) return `FX rates start ${min}. Pick a year from ${min} on.`;
      if (fromYear > max) return `FX rates end ${max}. Pick a year up to ${max}.`;
    }
  }
  return null;
}

export function compute() {
  if (!state.vm) return;
  readForm();
  const f = state.form;

  // Empty `from` → user hasn't picked a historical side yet. Don't crash,
  // don't call the gem; show a placeholder result.
  if (!f.from) {
    renderEmpty("Pick a starting year on the left.");
    return;
  }

  // Format check before mode derivation — `to` is already coerced to today
  // by toGemDate() when blank, so only validate non-empty inputs.
  if (!DATE_SHAPE.test(f.from)) {
    renderError("Use YYYY, YYYY-MM, or YYYY-MM-DD (e.g. 2008, 2008-03, 2008-03-14).");
    return;
  }
  if (f.to && !DATE_SHAPE.test(f.to)) {
    renderError("Use YYYY, YYYY-MM, or YYYY-MM-DD (e.g. 2008, 2008-03, 2008-03-14).");
    return;
  }

  const mode = deriveMode(f);

  if (mode === "identity") {
    renderResult({
      amount: f.amount,
      original_amount: f.amount,
      from_currency: f.fromCurrency,
      to_currency: f.toCurrency,
      from_date: fromGemDate(f),
      to_date: toGemDate(f),
    }, "identity");
    return;
  }

  const validation = validateForm(f, mode);
  if (validation) {
    renderError(validation);
    return;
  }

  try {
    // Always go through Timeprice.compare. Inflation = same currency on both
    // sides (Compare's FX leg is a no-op rate of 1). FX = same date on both
    // sides (Compare's inflation leg is a no-op ratio of 1).
    const rb = state.vm.eval(`
      require "timeprice"
      r = Timeprice.compare(
        amount: ${f.amount},
        from:   ["${f.fromCurrency}", "${fromGemDate(f)}"],
        to:     ["${f.toCurrency}",   "${toGemDate(f)}"],
      )
      JSON.generate(r.to_h)
    `);
    renderResult(JSON.parse(rb.toString()), mode);
  } catch (e) {
    console.error(e);
    const raw = (e && e.message) ? String(e.message) : String(e);
    renderError(humaniseError(raw));
  }
}
