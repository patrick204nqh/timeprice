import { describe, it, expect, beforeEach } from "vitest";
import { JSDOM } from "jsdom";
import { state } from "../src/state.js";
import { applyMetadata } from "../src/metadata.js";

function seedDom(toWhenValue, toCurrency = "USD") {
  const dom = new JSDOM(`
    <select id="from-currency"><option value="USD" selected>USD</option></select>
    <select id="to-currency"><option value="${toCurrency}" selected>${toCurrency}</option></select>
    <input id="from-when" value="2008-01-02">
    <input id="to-when" value="${toWhenValue}">
    <span id="meta-version"></span>
    <span id="meta-refresh"></span>
  `);
  global.document = dom.window.document;
  global.window = dom.window;
}

function fakeMetadata(currency, max) {
  return {
    version: "0.0.0",
    generated_at: "2026-05-15",
    currencies: [{ code: currency, name: `${currency} test` }],
    countries: [{
      code: "ZZ",
      name: "Testland",
      currency,
      cpi: { monthly: { min: "1990-01", max } },
    }],
  };
}

describe("applyMetadata clampSeedToCpiWindow", () => {
  beforeEach(() => {
    state.metadata = null;
    state.countryByCurrency = new Map();
  });

  it("clamps the to-when seed when today is past the destination CPI max", () => {
    seedDom("2026-05-15");
    state.metadata = fakeMetadata("USD", "2026-03");
    applyMetadata();
    expect(document.getElementById("to-when").value).toBe("2026-03");
  });

  it("leaves the to-when value alone when it's already inside the window", () => {
    seedDom("2024-06-15");
    state.metadata = fakeMetadata("USD", "2026-03");
    applyMetadata();
    expect(document.getElementById("to-when").value).toBe("2024-06-15");
  });

  it("does nothing when to-when is empty", () => {
    seedDom("");
    state.metadata = fakeMetadata("USD", "2026-03");
    applyMetadata();
    expect(document.getElementById("to-when").value).toBe("");
  });
});
