import { $ } from "./dom.js";
import { state } from "./state.js";
import { readForm, applyRangeForCountry } from "./form.js";
import { renderEmpty } from "./result.js";
import { renderSnippet } from "./snippet.js";
import { readUrl } from "./url.js";
import { bindCopyButtons, bindForm, bindFxForm, bindCompareForm } from "./events.js";
import { readFxForm } from "./fx.js";
import { readCompareForm } from "./compare.js";
import { bootRuby } from "./vm.js";

// Default form state matches what's hardcoded in index.html's result card.
// If the URL hash sets a different state, we clear the static markup so the
// user doesn't see a stale answer until the VM finishes warming up.
const DEFAULTS = { amount: 100, from: "1990-01", to: "2024-01", country: "US" };

function isDefaultForm(f) {
  return f.amount === DEFAULTS.amount
    && f.from === DEFAULTS.from
    && f.to === DEFAULTS.to
    && f.country === DEFAULTS.country;
}

readUrl();
applyRangeForCountry($("#inf-country").value);
readForm();
if (!isDefaultForm(state.form)) renderEmpty("Warming up Ruby VM…");
renderSnippet();
readFxForm();
readCompareForm();
bindCopyButtons();
bindForm();
bindFxForm();
bindCompareForm();
bootRuby();
