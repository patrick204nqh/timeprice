import { describe, it, expect, beforeEach, vi } from "vitest";
import { show, hide, bind } from "../src/affordance.js";
import { state } from "../src/state.js";

function seedDom() {
  document.body.innerHTML = `
    <div id="forecast-affordance" class="hidden">
      <button id="forecast-enable">📈 Forecast this date</button>
      <span id="forecast-affordance-message"></span>
    </div>
    <div id="calc-detail"></div>
  `;
}

describe("forecast affordance", () => {
  beforeEach(() => {
    seedDom();
    state.form = {
      amount: 100,
      fromCurrency: "USD", from: "2010",
      toCurrency: "VND", to: "2030",
      forecast: false,
    };
  });

  it("show() un-hides the slot and writes the message", () => {
    show({ offerForecast: true, message: "Vietnam inflation data ends 2025." });
    const slot = document.getElementById("forecast-affordance");
    expect(slot.classList.contains("hidden")).toBe(false);
    expect(document.getElementById("forecast-affordance-message").textContent)
      .toMatch(/Vietnam inflation data ends 2025/);
  });

  it("hide() re-applies the hidden class", () => {
    show({ offerForecast: true, message: "" });
    hide();
    expect(document.getElementById("forecast-affordance").classList.contains("hidden")).toBe(true);
  });

  it("button label reflects current forecast state", () => {
    state.form.forecast = false;
    show({ offerForecast: true, message: "" });
    expect(document.getElementById("forecast-enable").textContent).toMatch(/Forecast this date/);

    state.form.forecast = true;
    show({ offerForecast: true, message: "" });
    expect(document.getElementById("forecast-enable").textContent).toMatch(/Disable forecast/);
  });

  it("click toggles state.form.forecast and invokes compute + writeUrl", () => {
    const compute  = vi.fn();
    const writeUrl = vi.fn();
    bind({ compute, writeUrl });

    document.getElementById("forecast-enable").click();
    expect(state.form.forecast).toBe(true);
    expect(compute).toHaveBeenCalledOnce();
    expect(writeUrl).toHaveBeenCalledOnce();

    document.getElementById("forecast-enable").click();
    expect(state.form.forecast).toBe(false);
  });
});
