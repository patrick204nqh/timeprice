import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm } from "./form.js";

export function readUrl() {
  const h = location.hash.replace(/^#/, "");
  if (!h) return;
  const parts = h.split("/");
  const [tab, ...rest] = parts;
  if (tab === "inflation" && rest.length === 4) {
    const [country, amount, from, to] = rest;
    if ($("#inf-amount")) $("#inf-amount").value = amount;
    if ($("#inf-from"))   $("#inf-from").value   = from;
    if ($("#inf-to"))     $("#inf-to").value     = to;
    if ($("#inf-country")) $("#inf-country").value = country;
    readForm();
  }
}

export function writeUrl() {
  const { amount, from, to, country } = state.form;
  history.replaceState(null, "", `#inflation/${country}/${amount}/${from}/${to}`);
}
