import { describe, it, expect, beforeEach } from "vitest";
import { renderError, renderResult, renderSnippet } from "../src/view.js";
import { state } from "../src/state.js";

// Minimal hero + result-block DOM. Mirrors the bits of site/index.html that
// view.js writes into — anything it queries with $() needs to exist here or
// setText silently no-ops.
function seedDom() {
  document.body.innerHTML = `
    <h1>
      <span class="tabular" id="hero-from">$100 in 1990</span>
      <span> is worth </span>
      <span class="tabular text-emerald-700 dark:text-emerald-400" id="hero-to">$242.09 in 2024</span>
    </h1>
    <div id="calc-result" class="bg-stone-100 dark:bg-stone-800/50"></div>
    <div id="calc-amount-out"></div>
    <div id="calc-detail"></div>
    <div id="calc-meta"></div>
    <div id="forecast-block" class="hidden">
      <div id="forecast-low"></div>
      <div id="forecast-mid"></div>
      <div id="forecast-high"></div>
      <div id="forecast-basis"></div>
      <div id="forecast-caveat" class="hidden"></div>
    </div>
    <pre id="snippet"></pre>
  `;
}

const baseForm = () => ({
  amount: 100,
  fromCurrency: "USD",
  from: "1990",
  toCurrency: "USD",
  to: "2024",
});

const sampleOut = {
  amount: 242.09,
  original_amount: 100,
  from_currency: "USD",
  to_currency: "USD",
  from_date: "1990",
  to_date: "2024",
  fx_rate: 1,
  cpi_ratio: 2.4209,
  granularity: "annual",
};

describe("renderError", () => {
  beforeEach(() => {
    seedDom();
    state.form = baseForm();
    state.lastResultValid = true;
  });

  it("writes an em-dash to #hero-to (not an ellipsis)", () => {
    renderError("Boom");
    expect(document.querySelector("#hero-to").textContent).toBe("—");
    expect(document.querySelector("#hero-to").textContent).not.toBe("…");
  });

  it("drops the emerald accent on #hero-to and adds muted-stone classes", () => {
    renderError("Boom");
    const to = document.querySelector("#hero-to");
    expect(to.classList.contains("text-emerald-700")).toBe(false);
    expect(to.classList.contains("dark:text-emerald-400")).toBe(false);
    expect(to.classList.contains("text-stone-500")).toBe(true);
    expect(to.classList.contains("dark:text-stone-400")).toBe(true);
    expect(to.classList.contains("tabular")).toBe(false);
  });

  it("flips state.lastResultValid to false", () => {
    state.lastResultValid = true;
    renderError("Boom");
    expect(state.lastResultValid).toBe(false);
  });
});

describe("renderResult", () => {
  beforeEach(() => {
    seedDom();
    state.form = baseForm();
    state.lastResultValid = false;
  });

  it("flips state.lastResultValid to true", () => {
    renderResult(sampleOut);
    expect(state.lastResultValid).toBe(true);
  });

  it("writes the headline as `amount currency` — no mode badge prefix", () => {
    renderResult(sampleOut);
    expect(document.querySelector("#calc-amount-out").textContent).toBe("242.09 USD");
  });

  it("surfaces CPI + granularity in the meta line when dates differ", () => {
    renderResult(sampleOut);
    const meta = document.querySelector("#calc-meta").textContent;
    expect(meta).toContain("CPI");
    expect(meta).toContain("annual");
  });

  it("surfaces FX disclosure in the meta line when currencies differ", () => {
    const out = { ...sampleOut, to_currency: "VND", to_date: "1990", from_date: "1990", fx_rate: 23000, cpi_ratio: 1, granularity: "daily" };
    state.form = { ...baseForm(), toCurrency: "VND", to: "1990" };
    renderResult(out);
    const meta = document.querySelector("#calc-meta").textContent;
    expect(meta).toContain("FX");
    expect(meta).not.toContain("CPI");
  });

  it("renders identity (same currency, same date) without a disclosure line claiming work", () => {
    const out = {
      amount: 100, original_amount: 100,
      from_currency: "USD", to_currency: "USD",
      from_date: "2020", to_date: "2020",
      fx_rate: 1, cpi_ratio: 1,
    };
    state.form = { ...baseForm(), from: "2020", to: "2020" };
    renderResult(out);
    const meta = document.querySelector("#calc-meta").textContent;
    expect(meta).toBe("No conversion needed");
  });

  it("restores emerald accent + tabular on #hero-to after a prior error", () => {
    renderError("Boom");
    renderResult(sampleOut);
    const to = document.querySelector("#hero-to");
    expect(to.classList.contains("text-emerald-700")).toBe(true);
    expect(to.classList.contains("dark:text-emerald-400")).toBe(true);
    expect(to.classList.contains("tabular")).toBe(true);
    expect(to.classList.contains("text-stone-500")).toBe(false);
  });
});

describe("renderResult with forecast", () => {
  beforeEach(() => {
    seedDom();
    state.form = baseForm();
    state.lastResultValid = false;
  });

  it("populates the forecast block and tags the hero", () => {
    renderResult({
      amount: 4297876, original_amount: 100,
      from_currency: "USD", to_currency: "VND",
      from_date: "2010", to_date: "2030",
      granularity: "forecast",
      fx_rate: 18612.92, cpi_ratio: 2.3091,
      forecast: {
        basis_kind: "cpi",
        projection_method: "cagr_trailing",
        window_years: 10,
        sigma_pct: 0.01047,
        last_known_date: "2026-03",
        horizon_months: 46,
        low: 4133277,
        high: 4467270,
        warnings: [],
      },
    });

    expect(document.getElementById("forecast-block").classList.contains("hidden")).toBe(false);
    expect(document.getElementById("forecast-low").textContent).toMatch(/4,133,277/);
    expect(document.getElementById("forecast-mid").textContent).toMatch(/4,297,876/);
    expect(document.getElementById("forecast-high").textContent).toMatch(/4,467,270/);
    expect(document.getElementById("forecast-basis").textContent).toMatch(/trailing 10y/);
    expect(document.getElementById("forecast-basis").textContent).toMatch(/2026-03/);
    expect(document.getElementById("forecast-caveat").classList.contains("hidden")).toBe(true);
    // Hero tagged
    expect(document.getElementById("hero-to").textContent).toMatch(/forecast/i);
  });

  it("shows the caveat when horizon_exceeds_cap warning is present", () => {
    renderResult({
      amount: 100, original_amount: 100,
      from_currency: "USD", to_currency: "VND",
      from_date: "2010", to_date: "2040",
      granularity: "forecast",
      fx_rate: 18000, cpi_ratio: 4,
      forecast: {
        basis_kind: "cpi", projection_method: "cagr_trailing",
        window_years: 10, sigma_pct: 0.01,
        last_known_date: "2026-03", horizon_months: 166,
        low: 90, high: 110,
        warnings: ["horizon_exceeds_cap"],
      },
    });
    expect(document.getElementById("forecast-caveat").classList.contains("hidden")).toBe(false);
    expect(document.getElementById("forecast-caveat").textContent).toMatch(/illustrative/);
  });

  it("hides the forecast block on measured (non-forecast) results", () => {
    renderResult({
      amount: 200, original_amount: 100,
      from_currency: "USD", to_currency: "VND",
      from_date: "2010", to_date: "2024",
      granularity: "annual",
      fx_rate: 18612.92, cpi_ratio: 2.0,
      // no forecast key
    });
    expect(document.getElementById("forecast-block").classList.contains("hidden")).toBe(true);
    expect(document.getElementById("hero-to").textContent).not.toMatch(/forecast/i);
  });
});

describe("renderSnippet", () => {
  beforeEach(() => {
    seedDom();
    state.form = baseForm();
  });

  it("writes a comment placeholder when lastResultValid is false", () => {
    state.lastResultValid = false;
    renderSnippet();
    const text = document.querySelector("#snippet").textContent;
    expect(text).toBe("# (form is currently invalid — fix the inputs above)");
    expect(text).not.toContain("Timeprice.");
  });

  it("writes a real Ruby call when lastResultValid is true", () => {
    state.lastResultValid = true;
    renderSnippet();
    const text = document.querySelector("#snippet").textContent;
    expect(text).toContain('require "timeprice"');
    expect(text).toContain("Timeprice.");
  });
});
