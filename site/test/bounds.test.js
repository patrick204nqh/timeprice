import { describe, it, expect } from "vitest";
import { computeYearBounds, computeRangeHint } from "../src/bounds.js";

// US has CPI from 1990; VN has CPI from 1995. FX coverage is 1999-01-04..2026-05-10.
// Pairings are deliberately asymmetric so we catch the union bug where
// either country's window would leak into the other's bounds.
const COUNTRIES = new Map([
  ["USD", { code: "US", name: "United States", currency: "USD", cpi: { monthly: { min: "1990-01", max: "2026-03" }, annual: { min: "1913", max: "2025" } } }],
  ["VND", { code: "VN", name: "Vietnam",       currency: "VND", cpi: { monthly: { min: "1995-01", max: "2024-12" } } }],
  ["EUR", { code: "EU", name: "Eurozone",      currency: "EUR", cpi: { monthly: { min: "1996-01", max: "2026-02" } } }],
]);
const FX = { daily_min: "1999-01-04", daily_max: "2026-05-10" };

const form = (overrides = {}) => ({
  amount: 100,
  fromCurrency: "USD", from: "2000",
  toCurrency: "USD",   to: "2020",
  ...overrides,
});

describe("computeYearBounds", () => {
  it("uses destination CPI in inflation mode — VN destination narrows to 1995", () => {
    const f = form({ fromCurrency: "VND", toCurrency: "VND" });
    expect(computeYearBounds(f, "inflation", COUNTRIES, FX)).toEqual({ min: "1995", max: "2024" });
  });

  it("uses destination CPI in inflation mode — US destination opens to 1990", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "USD" });
    expect(computeYearBounds(f, "inflation", COUNTRIES, FX)).toEqual({ min: "1990", max: "2026" });
  });

  it("uses destination CPI in compare mode — USD->VND clamps to VN range", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "VND" });
    expect(computeYearBounds(f, "compare", COUNTRIES, FX)).toEqual({ min: "1995", max: "2024" });
  });

  it("uses destination CPI in compare mode — VND->USD opens to US range", () => {
    const f = form({ fromCurrency: "VND", toCurrency: "USD" });
    expect(computeYearBounds(f, "compare", COUNTRIES, FX)).toEqual({ min: "1990", max: "2026" });
  });

  it("uses FX coverage in fx mode regardless of destination CPI", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "VND" });
    expect(computeYearBounds(f, "fx", COUNTRIES, FX)).toEqual({ min: "1999", max: "2026" });
  });

  it("returns null in identity mode (no narrowing)", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "USD", from: "2020", to: "2020" });
    expect(computeYearBounds(f, "identity", COUNTRIES, FX)).toBeNull();
  });

  it("returns null when destination has no metadata yet", () => {
    const f = form({ toCurrency: "XYZ" });
    expect(computeYearBounds(f, "inflation", COUNTRIES, FX)).toBeNull();
  });
});

describe("computeRangeHint", () => {
  it("FX mode shows year-grain coverage with annual fallback note", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "EUR", from: "2020", to: "2020" });
    expect(computeRangeHint(f, "fx", COUNTRIES, FX))
      .toBe("Daily FX: 1999–2026 · annual fallback for earlier years");
  });

  it("identity mode shows nothing — same currency, same date, no conversion", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "USD", from: "2020", to: "2020" });
    expect(computeRangeHint(f, "identity", COUNTRIES, FX)).toBe("");
  });

  it("inflation mode shows destination CPI window", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "USD" });
    expect(computeRangeHint(f, "inflation", COUNTRIES, FX))
      .toBe("United States inflation data: 1990 – 2026");
  });

  it("compare mode shows destination CPI window (destination is the inflation leg)", () => {
    const f = form({ fromCurrency: "USD", toCurrency: "VND" });
    expect(computeRangeHint(f, "compare", COUNTRIES, FX))
      .toBe("Vietnam inflation data: 1995 – 2024");
  });
});
