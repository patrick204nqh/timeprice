import { describe, it, expect, beforeEach, vi } from "vitest";
import { humaniseError, validateForm, readForm, todayIso, DATE_SHAPE, fromGemDate, toGemDate, compute } from "../src/compute.js";
import { state } from "../src/state.js";

const form = (overrides = {}) => ({
  amount: 100,
  fromCurrency: "USD",
  from: "1990",
  toCurrency: "USD",
  to: "2024",
  ...overrides,
});

function seedDom({ from = "", to = "" } = {}) {
  document.body.innerHTML = `
    <input id="calc-amount" value="100">
    <select id="from-currency"><option value="USD" selected>USD</option></select>
    <select id="to-currency"><option value="USD" selected>USD</option></select>
    <input id="from-when" value="${from}">
    <input id="to-when" value="${to}">
  `;
}

describe("DATE_SHAPE", () => {
  it.each(["2008", "2008-03", "2008-03-14"])("accepts %s", (s) => {
    expect(DATE_SHAPE.test(s)).toBe(true);
  });
  it.each(["", "08", "2008-3", "2008/03", "2008-03-1", "garbage"])("rejects %s", (s) => {
    expect(DATE_SHAPE.test(s)).toBe(false);
  });
});

describe("readForm", () => {
  it("returns {from, to} as trimmed strings", () => {
    seedDom({ from: "  2008-03  ", to: "2024" });
    readForm();
    expect(state.form.from).toBe("2008-03");
    expect(state.form.to).toBe("2024");
  });

  it("leaves `to` empty when the input is empty (compute() coerces it to today)", () => {
    seedDom({ from: "1990", to: "" });
    readForm();
    expect(state.form.to).toBe("");
  });
});

describe("todayIso", () => {
  it("returns YYYY-MM-DD", () => {
    expect(todayIso()).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});

describe("fromGemDate / toGemDate", () => {
  it("fromGemDate returns f.from verbatim", () => {
    expect(fromGemDate(form({ from: "2008-03" }))).toBe("2008-03");
  });

  it("toGemDate returns f.to verbatim when set", () => {
    expect(toGemDate(form({ to: "2024" }))).toBe("2024");
  });

  it("toGemDate falls back to today when f.to is empty", () => {
    expect(toGemDate(form({ to: "" }))).toBe(todayIso());
  });
});

describe("humaniseError", () => {
  it("rewrites out-of-range with min/max years", () => {
    const msg = humaniseError('Date "1850" out of supported range "1990-01".."2026-03"');
    expect(msg).toBe("That date is outside our data range. Try a year between 1990 and 2026.");
  });

  it("strips Error: prefix and trims first line", () => {
    expect(humaniseError("Error: Unsupported currency XYZ")).toContain("isn't in our dataset");
  });

  it("recognises unsupported country", () => {
    expect(humaniseError("Unsupported country ZZ")).toContain("country isn't in our dataset");
  });

  it("recognises missing data point", () => {
    expect(humaniseError("Data not found for 2024-13")).toContain("nearby year");
  });

  it.each([
    "FX triangulation date mismatch for EUR->VND on 2002-06-30",
    "No FX rate for USD->VND on or before 2010-01-01",
    "something exploded (Timeprice::DataNotFound)",
  ])("humanises ruby FX/data errors instead of leaking them: %s", (msg) => {
    expect(humaniseError(msg)).toContain("nearby year");
  });

  it("falls through to raw first line", () => {
    expect(humaniseError("Something broke\nstack trace")).toBe("Something broke");
  });

  it("returns a default when input is empty", () => {
    expect(humaniseError("")).toBe("Calculation failed.");
  });
});

describe("validateForm", () => {
  beforeEach(() => {
    state.countryByCurrency = new Map([
      ["USD", { code: "US", name: "United States", currency: "USD", cpi: { monthly: { min: "1990-01", max: "2026-03" }, annual: { min: "1990", max: "2025" } } }],
      ["EUR", { code: "EU", name: "Eurozone",      currency: "EUR", cpi: { monthly: { min: "1996-01", max: "2026-02" } } }],
    ]);
    state.metadata = { fx: { daily_min: "1999-01-04", daily_max: "2026-05-10" } };
  });

  it("returns null when years are within range (same currency, dates differ)", () => {
    expect(validateForm(form())).toBeNull();
  });

  it("flags too-early year against destination CPI start", () => {
    const msg = validateForm(form({ from: "1850" }));
    expect(msg).toMatch(/United States.*1990/);
  });

  it("flags too-late year against destination CPI end", () => {
    const msg = validateForm(form({ to: "2099" }));
    expect(msg).toMatch(/United States.*2026/);
  });

  it("checks FX bounds when currencies differ and dates match", () => {
    const f = form({ from: "1980", to: "1980", toCurrency: "EUR" });
    expect(validateForm(f)).toMatch(/FX rates start 1999/);
  });

  it("checks FX upper bound when currencies differ and dates match", () => {
    const f = form({ from: "2099", to: "2099", toCurrency: "EUR" });
    expect(validateForm(f)).toMatch(/FX rates end 2026/);
  });

  it("returns null when both currencies and dates differ and inputs are in range", () => {
    const f = form({ from: "2000", to: "2020", toCurrency: "EUR" });
    expect(validateForm(f)).toBeNull();
  });

  it("returns null gracefully when destination has no metadata (same currency)", () => {
    const f = form({ fromCurrency: "XYZ", toCurrency: "XYZ" });
    expect(validateForm(f)).toBeNull();
  });

  it("skips CPI bound check when dates match (CPI leg is a no-op)", () => {
    // Same date — CPI ratio = 1.0; we shouldn't fault the year for being
    // outside the CPI window because we're not consulting CPI.
    const f = form({ from: "1850", to: "1850", toCurrency: "EUR" });
    // Currencies also differ here so FX bound kicks in instead; the point
    // is the message mentions FX, not US/EU inflation.
    expect(validateForm(f)).toMatch(/FX rates start/);
  });

  it("skips FX bound check when currencies match (FX leg is a no-op)", () => {
    // Same currency, dates within CPI window — no FX bound to violate.
    const f = form({ from: "1995", to: "2024" });
    expect(validateForm(f)).toBeNull();
  });
});

describe("compute with forecast", () => {
  const countryByCurrency = new Map([
    ["USD", { code: "US", name: "United States", currency: "USD", cpi: { monthly: { min: "1990-01", max: "2026-03" }, annual: { min: "1990", max: "2025" } } }],
    ["VND", { code: "VN", name: "Vietnam",       currency: "VND", cpi: { monthly: { min: "1995-01", max: "2026-03" }, annual: { min: "1995", max: "2025" } } }],
  ]);

  function seedForecastDom({ from = "2010", to = "2024", forecastChecked = false } = {}) {
    document.body.innerHTML = `
      <input id="calc-amount" value="100">
      <select id="from-currency"><option value="USD" selected>USD</option></select>
      <select id="to-currency"><option value="VND" selected>VND</option></select>
      <input id="from-when" value="${from}">
      <input id="to-when" value="${to}">
      <input id="forecast-toggle" type="checkbox" ${forecastChecked ? "checked" : ""}>
    `;
  }

  beforeEach(() => {
    state.countryByCurrency = countryByCurrency;
    state.metadata = { fx: { daily_min: "1999-01-04", daily_max: "2026-05-10" } };
  });

  it("forecast: true is sent to the gem when toggle is on", () => {
    seedForecastDom({ forecastChecked: true });
    const forecastResult = {
      amount: 1000, original_amount: 100, from_currency: "USD",
      to_currency: "VND", from_date: "2010", to_date: "2024",
      granularity: "forecast", fx_rate: 18000, cpi_ratio: 2.3,
      forecast: { low: 950, high: 1050, last_known_date: "2026-03", warnings: [] },
    };
    const evalSpy = vi.fn(() => ({ toString: () => JSON.stringify(forecastResult) }));
    state.vm = { eval: evalSpy };

    compute();

    expect(evalSpy.mock.calls.length).toBeGreaterThan(0);
    const rubySource = evalSpy.mock.calls[0][0];
    expect(rubySource).toMatch(/forecast:\s*true/);
  });

  it("forecast: false is sent to the gem when toggle is off", () => {
    seedForecastDom({ forecastChecked: false });
    const normalResult = {
      amount: 1000, original_amount: 100, from_currency: "USD",
      to_currency: "VND", from_date: "2010", to_date: "2024",
      granularity: "annual", fx_rate: 18000, cpi_ratio: 2.3,
    };
    const evalSpy = vi.fn(() => ({ toString: () => JSON.stringify(normalResult) }));
    state.vm = { eval: evalSpy };

    compute();

    expect(evalSpy.mock.calls.length).toBeGreaterThan(0);
    const rubySource = evalSpy.mock.calls[0][0];
    expect(rubySource).toMatch(/forecast:\s*false/);
  });
});
