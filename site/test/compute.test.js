import { describe, it, expect, beforeEach } from "vitest";
import { deriveMode, humaniseError, validateForm, readForm, todayIso, DATE_SHAPE, fromGemDate, toGemDate } from "../src/compute.js";
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

describe("deriveMode", () => {
  it("identity when currency and date match", () => {
    expect(deriveMode(form({ from: "2000", to: "2000" }))).toBe("identity");
  });

  it("inflation when currency matches but date differs", () => {
    expect(deriveMode(form())).toBe("inflation");
  });

  it("fx when date matches but currency differs", () => {
    expect(deriveMode(form({ from: "2020", to: "2020", toCurrency: "EUR" }))).toBe("fx");
  });

  it("compare when both currency and date differ", () => {
    expect(deriveMode(form({ toCurrency: "EUR" }))).toBe("compare");
  });

  it("accepts full ISO dates as well as years", () => {
    const f = form({ from: "2020-06-15", to: "2020-06-15", toCurrency: "EUR" });
    expect(deriveMode(f)).toBe("fx");
  });

  it("empty `to` defaults to today for mode comparison", () => {
    const f = form({ from: "1990", to: "" });
    // Same currency, different date (1990 vs today) → inflation
    expect(deriveMode(f)).toBe("inflation");
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

  it("returns null when years are within range", () => {
    expect(validateForm(form(), "inflation")).toBeNull();
  });

  it("flags too-early year against destination CPI start", () => {
    const msg = validateForm(form({ from: "1850" }), "inflation");
    expect(msg).toMatch(/United States.*1990/);
  });

  it("flags too-late year against destination CPI end", () => {
    const msg = validateForm(form({ to: "2099" }), "inflation");
    expect(msg).toMatch(/United States.*2026/);
  });

  it("checks FX bounds in fx mode", () => {
    const f = form({ from: "1980", to: "1980", toCurrency: "EUR" });
    expect(validateForm(f, "fx")).toMatch(/FX rates start 1999/);
  });

  it("checks FX upper bound in fx mode", () => {
    const f = form({ from: "2099", to: "2099", toCurrency: "EUR" });
    expect(validateForm(f, "fx")).toMatch(/FX rates end 2026/);
  });

  it("returns null in compare mode when both sides are valid", () => {
    const f = form({ from: "2000", to: "2020", toCurrency: "EUR" });
    expect(validateForm(f, "compare")).toBeNull();
  });

  it("returns null gracefully when destination has no metadata", () => {
    const f = form({ toCurrency: "XYZ" });
    expect(validateForm(f, "inflation")).toBeNull();
  });
});
