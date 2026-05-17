import { describe, it, expect, beforeEach } from "vitest";
import { readUrl, writeUrl, applyPoint } from "../src/url.js";
import { readForm, todayIso } from "../src/compute.js";
import { state } from "../src/state.js";

// Minimal calculator DOM. url.js writes into the same `#from-when`/`#to-when`
// inputs the rest of the calculator uses — anything it can't find with $()
// silently no-ops, so the fields must exist for the round-trip to be real.
function seedDom({ from = "", to = "", amount = "100" } = {}) {
  document.body.innerHTML = `
    <input id="calc-amount" value="${amount}">
    <select id="from-currency"><option value="USD" selected>USD</option><option value="EUR">EUR</option></select>
    <select id="to-currency"><option value="USD" selected>USD</option><option value="EUR">EUR</option></select>
    <input id="from-when" value="${from}">
    <input id="to-when" value="${to}">
  `;
}

function setHash(s) { window.location.hash = s; }

describe("applyPoint", () => {
  beforeEach(() => seedDom());

  it("populates currency + date from a YYYY-only spec", () => {
    applyPoint("USD:2008", "from");
    expect(document.querySelector("#from-currency").value).toBe("USD");
    expect(document.querySelector("#from-when").value).toBe("2008");
  });

  it("populates a month-grain spec", () => {
    applyPoint("USD:2008-03", "from");
    expect(document.querySelector("#from-when").value).toBe("2008-03");
  });

  it("populates a day-grain spec", () => {
    applyPoint("USD:2008-03-14", "from");
    expect(document.querySelector("#from-when").value).toBe("2008-03-14");
  });

  it("leaves the date field untouched when the spec has an empty date (USD:)", () => {
    seedDom({ to: "2026-05-15" });
    applyPoint("USD:", "to");
    // Today-seed must survive an empty `to=USD:` spec — that's the whole
    // point of treating empty-date as "no date" rather than "blank it out."
    expect(document.querySelector("#to-when").value).toBe("2026-05-15");
  });

  it("leaves the date field untouched when the spec is currency-only (USD)", () => {
    seedDom({ to: "2026-05-15" });
    applyPoint("USD", "to");
    expect(document.querySelector("#to-when").value).toBe("2026-05-15");
  });
});

describe("writeUrl", () => {
  beforeEach(() => {
    seedDom();
    setHash("");
  });

  it("writes the full hash when both sides have dates", () => {
    state.form = { amount: 100, fromCurrency: "USD", from: "1990", toCurrency: "EUR", to: "2024", };
    writeUrl();
    expect(location.hash).toContain("from=USD%3A1990");
    expect(location.hash).toContain("to=EUR%3A2024");
    expect(location.hash).toContain("amount=100");
  });

  it("omits the trailing colon when `from` is empty", () => {
    state.form = { amount: 100, fromCurrency: "USD", from: "", toCurrency: "EUR", to: "2024", };
    writeUrl();
    // `from=USD` (not `from=USD%3A`) — no malformed stub in shared URLs.
    expect(location.hash).toMatch(/from=USD(&|$)/);
    expect(location.hash).not.toContain("from=USD%3A&");
  });

  it("omits the trailing colon when `to` is empty", () => {
    state.form = { amount: 100, fromCurrency: "USD", from: "1990", toCurrency: "EUR", to: "", };
    writeUrl();
    expect(location.hash).toMatch(/to=EUR(&|$)/);
  });
});

describe("URL forecast param", () => {
  it("reads forecast=1 into the toggle on load", () => {
    document.body.innerHTML = `
      <input id="calc-amount" />
      <select id="from-currency"><option value="USD" selected>USD</option></select>
      <select id="to-currency"><option value="VND" selected>VND</option></select>
      <input id="from-when" /> <input id="to-when" />
      <input type="checkbox" id="forecast-toggle" />
    `;
    location.hash = "#from=USD:2010&to=VND:2030&amount=100&forecast=1";
    readUrl();
    expect(document.getElementById("forecast-toggle").checked).toBe(true);
  });

  it("leaves toggle unchecked when forecast param is absent", () => {
    document.body.innerHTML = `
      <input id="calc-amount" />
      <select id="from-currency"><option value="USD" selected>USD</option></select>
      <select id="to-currency"><option value="VND" selected>VND</option></select>
      <input id="from-when" /> <input id="to-when" />
      <input type="checkbox" id="forecast-toggle" />
    `;
    location.hash = "#from=USD:2010&to=VND:2024&amount=100";
    readUrl();
    expect(document.getElementById("forecast-toggle").checked).toBe(false);
  });

  it("writes forecast=1 when state.form.forecast is true, omits it when false", () => {
    seedDom();
    setHash("");
    state.form = {
      amount: 100, fromCurrency: "USD", from: "2010",
      toCurrency: "VND", to: "2030", forecast: true,
    };
    writeUrl();
    expect(location.hash).toMatch(/forecast=1/);

    state.form.forecast = false;
    writeUrl();
    expect(location.hash).not.toMatch(/forecast=/);
  });
});

describe("URL round-trip", () => {
  beforeEach(() => seedDom());

  it("survives a day-grain date verbatim", () => {
    state.form = { amount: 100, fromCurrency: "USD", from: "2008-03-14", toCurrency: "USD", to: "2024", };
    writeUrl();
    // Wipe inputs, then re-hydrate from the URL.
    seedDom();
    readUrl();
    expect(document.querySelector("#from-when").value).toBe("2008-03-14");
    expect(document.querySelector("#to-when").value).toBe("2024");
  });

  it("survives a month-grain date verbatim", () => {
    state.form = { amount: 100, fromCurrency: "USD", from: "2008-03", toCurrency: "USD", to: "2024", };
    writeUrl();
    seedDom();
    readUrl();
    expect(document.querySelector("#from-when").value).toBe("2008-03");
  });

  it("survives empty `from` without leaking a colon stub or losing the today-seed", () => {
    // Simulate the first-paint sequence: today-seed lands in `to`, then
    // writeUrl() runs (e.g. on first user input), then a reload calls readUrl().
    const today = todayIso();
    seedDom({ to: today });
    state.form = { amount: 100, fromCurrency: "USD", from: "", toCurrency: "USD", to: today, };
    writeUrl();

    // Reload: the `to` input would re-seed to today before readUrl runs.
    seedDom({ to: today });
    readUrl();
    expect(document.querySelector("#from-when").value).toBe("");
    expect(document.querySelector("#to-when").value).toBe(today);
    readForm();
    expect(state.form.from).toBe("");
    expect(state.form.to).toBe(today);
  });
});
