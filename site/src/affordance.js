import { state } from "./state.js";

// The inline "📈 Forecast this date" button replaces the old #forecast-toggle.
// It only surfaces in one place — the result/error slot — and only when
// validateForm explicitly opts into it via `{ offerForecast: true }`. The
// affordance writes `state.form.forecast` directly; readForm picks it up
// from there (no DOM element to read).

const SLOT_ID = "forecast-affordance";
const BUTTON_ID = "forecast-enable";
const MESSAGE_ID = "forecast-affordance-message";

export function show(reason) {
  const slot = document.getElementById(SLOT_ID);
  if (!slot) return;
  slot.classList.remove("hidden");
  const msg = document.getElementById(MESSAGE_ID);
  if (msg && reason?.message) msg.textContent = reason.message;
  syncButtonLabel();
}

export function hide() {
  const slot = document.getElementById(SLOT_ID);
  if (!slot) return;
  slot.classList.add("hidden");
}

function syncButtonLabel() {
  const btn = document.getElementById(BUTTON_ID);
  if (!btn) return;
  btn.textContent = state.form?.forecast
    ? "✕ Disable forecast"
    : "📈 Forecast this date";
}

// Wire the click handler. The caller supplies `compute` + `writeUrl` so we
// stay decoupled from those modules (and avoid an import cycle through
// compute.js, which already imports view.js).
export function bind({ compute, writeUrl }) {
  const btn = document.getElementById(BUTTON_ID);
  if (!btn) return;
  btn.addEventListener("click", (e) => {
    e.preventDefault();
    state.form.forecast = !state.form.forecast;
    syncButtonLabel();
    writeUrl?.();
    compute?.();
  });
}
