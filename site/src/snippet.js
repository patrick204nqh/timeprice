import { setText } from "./dom.js";
import { state } from "./state.js";

export function renderSnippet() {
  const { amount, from, to, country } = state.form;
  setText("#snippet", `require "timeprice"

Timeprice.inflation(
  amount: ${amount},
  from:   "${from}",
  to:     "${to}",
  country: "${country}",
).amount`);
}
