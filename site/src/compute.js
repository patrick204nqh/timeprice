import { $, setText, fmtNumber } from "./dom.js";
import { state } from "./state.js";
import { CURRENCY_SYMBOLS } from "./data.js";

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

// Read the calculator form. Day pickers (when the "Use specific dates"
// disclosure is open and filled) override the year inputs — they're a
// power-user knob for FX where Jun 15 vs Jun 16 matters.
export function readForm() {
  const useDates = !$("#precise-wrap")?.hidden;
  const fromYear = $("#from-year").value;
  const toYear = $("#to-year").value;
  const fromDate = useDates ? $("#from-date").value : "";
  const toDate = useDates ? $("#to-date").value : "";
  state.form = {
    amount: parseFloat($("#calc-amount").value) || 0,
    fromCurrency: $("#from-currency").value,
    fromYear, fromDate,
    toCurrency: $("#to-currency").value,
    toYear, toDate,
  };
}

// What the gem actually sees — a year string, a YYYY-MM, or a full date.
function fromGemDate(f) { return f.fromDate || f.fromYear; }
function toGemDate(f)   { return f.toDate   || f.toYear;   }

// Mode is self-derived. Same currency, different date → inflation.
// Same date, different currency → FX. Different on both axes → compare.
function deriveMode(f) {
  const sameCurrency = f.fromCurrency === f.toCurrency;
  const sameDate = fromGemDate(f) === toGemDate(f);
  if (sameCurrency && sameDate) return "identity";
  if (sameCurrency) return "inflation";
  if (sameDate) return "fx";
  return "compare";
}

const COUNTRY_FOR_CURRENCY_FALLBACK = { USD: "US", GBP: "UK", EUR: "EU", JPY: "JP", VND: "VN" };
function countryFor(currency) {
  return state.metadata?.countries?.find((c) => c.currency === currency)?.code
      || COUNTRY_FOR_CURRENCY_FALLBACK[currency]
      || currency;
}

function modeLabel(mode, f) {
  switch (mode) {
    case "inflation": return `Inflation — ${countryFor(f.toCurrency)} CPI`;
    case "fx":        return "Exchange rate";
    case "compare":   return "FX + Inflation";
    default:          return "Same currency, same date";
  }
}

function metaLine(mode, r, f) {
  switch (mode) {
    case "inflation":
      return `${countryFor(f.toCurrency)} CPI · ${r.granularity || ""}`.replace(/ · $/, "");
    case "fx":
      return `Rate on ${humanDate(f.fromDate || `${f.fromYear}-06-15`)}`;
    case "compare":
      return `FX on ${humanDate(f.fromDate || `${f.fromYear}-06-15`)} · ${countryFor(f.toCurrency)} CPI to ${humanDate(toGemDate(f))}`;
    default:
      return "No conversion needed";
  }
}

export function renderHero(out) {
  const f = state.form;
  const sym = symbolFor(f.fromCurrency);
  setText("#hero-from", `${sym}${fmtNumber(f.amount, decimalsFor(f.fromCurrency))} in ${humanDate(fromGemDate(f))}`);
  if (out) {
    const toSym = symbolFor(out.to_currency || f.toCurrency);
    setText("#hero-to", `${toSym}${fmtNumber(out.amount, decimalsFor(out.to_currency))} in ${humanDate(out.to_date)}`);
  } else {
    setText("#hero-to", `… in ${humanDate(toGemDate(f))}`);
  }
}

function renderResult(out, mode) {
  const f = state.form;
  const dec = decimalsFor(out.to_currency);
  setText("#calc-mode", modeLabel(mode, f));
  setText("#calc-amount-out", `${fmtNumber(out.amount, dec)} ${out.to_currency}`);
  setText(
    "#calc-detail",
    `${fmtNumber(out.original_amount, decimalsFor(out.from_currency))} ${out.from_currency} in ${humanDate(out.from_date)} → ${fmtNumber(out.amount, dec)} ${out.to_currency} in ${humanDate(out.to_date)}`,
  );
  setText("#calc-meta", metaLine(mode, out, f));
  renderHero(out);
}

export function renderError(message) {
  setText("#calc-mode", "Error");
  setText("#calc-amount-out", "—");
  setText("#calc-detail", message);
  setText("#calc-meta", "");
  renderHero(null);
}

export function renderEmpty(message = "Warming up Ruby VM…") {
  setText("#calc-mode", "");
  setText("#calc-amount-out", "—");
  setText("#calc-detail", message);
  setText("#calc-meta", "");
  renderHero(null);
}

export function renderSnippet() {
  const f = state.form;
  const fromDate = fromGemDate(f);
  const toDate = toGemDate(f);
  const mode = deriveMode(f);
  let body;
  if (mode === "inflation") {
    body = `Timeprice.inflation(
  amount: ${f.amount},
  from:   "${fromDate}",
  to:     "${toDate}",
  country: "${countryFor(f.toCurrency)}",
).amount`;
  } else if (mode === "fx") {
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

// Translate gem error messages into something a civilian can act on. The
// gem's defaults are technically accurate but full of jargon — "Date "1850"
// out of supported range" tells the user what's wrong without telling them
// what to do about it.
function humaniseError(raw) {
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
  if (/Data not found|No FX data/i.test(first)) {
    return "No data point for that combination. Try a nearby year.";
  }
  return first || "Calculation failed.";
}

// Pre-VM validation. Catches the obvious "wrong year" mistakes without
// round-tripping through the VM — and lets us reference the destination
// country by name when explaining the bound.
function validateForm(f, mode) {
  const fromYear = Number((f.fromDate || f.fromYear).slice(0, 4));
  const toYear   = Number((f.toDate   || f.toYear).slice(0, 4));
  if (!fromYear || !toYear) return null;

  if (mode === "inflation" || mode === "compare") {
    const country = countryFor(f.toCurrency);
    const c = state.metadata?.countries?.find((x) => x.code === country);
    const widest = c && (c.cpi.monthly || c.cpi.quarterly || c.cpi.annual);
    if (widest) {
      const min = Number(widest.min.slice(0, 4));
      const max = Number(widest.max.slice(0, 4));
      if (toYear < min || fromYear < min) {
        return `${country} CPI data starts ${min}. Pick a year from ${min} on.`;
      }
      if (toYear > max || fromYear > max) {
        return `${country} CPI data ends ${max}. Pick a year up to ${max}.`;
      }
    }
  }

  if (mode === "fx" || mode === "compare") {
    const fx = state.metadata?.fx;
    if (fx?.daily_min && fx?.daily_max) {
      const min = Number(fx.daily_min.slice(0, 4));
      const max = Number(fx.daily_max.slice(0, 4));
      const yearToCheck = mode === "fx" ? fromYear : fromYear;
      if (yearToCheck < min) return `FX rates start ${min}. Pick a year from ${min} on.`;
      if (yearToCheck > max) return `FX rates end ${max}. Pick a year up to ${max}.`;
    }
  }
  return null;
}

export function compute() {
  if (!state.vm) return;
  readForm();
  const f = state.form;
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

// Range hint reflects the destination country's CPI window (the binding
// constraint when inflation is in play). Currency-only mode (same date) is
// FX-limited and gets its hint from FX coverage.
export function refreshRangeHint() {
  const f = state.form;
  const mode = deriveMode(f);
  if (mode === "fx" || mode === "identity") {
    const fx = state.metadata?.fx;
    if (fx?.daily_min && fx?.daily_max) {
      setText("#calc-range-hint", `FX coverage: ${fx.daily_min} – ${fx.daily_max}`);
    } else {
      setText("#calc-range-hint", "");
    }
    return;
  }
  const country = countryFor(f.toCurrency);
  const c = state.metadata?.countries?.find((x) => x.code === country);
  if (!c) { setText("#calc-range-hint", ""); return; }
  const cpi = c.cpi || {};
  const widest = cpi.monthly || cpi.quarterly || cpi.annual;
  if (!widest) { setText("#calc-range-hint", ""); return; }
  setText("#calc-range-hint", `${country} CPI coverage: ${widest.min.slice(0, 4)} – ${widest.max.slice(0, 4)}`);
}
