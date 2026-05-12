import { state } from "./state.js";
import { readForm, renderSnippet, renderHero, renderEmpty, refreshRangeHint } from "./compute.js";
import { readUrl } from "./url.js";
import { bindCopyButtons, bindCalcForm, bindExampleChips } from "./events.js";
import { bootRuby } from "./vm.js";
import { initTheme } from "./theme.js";

// Default form state mirrors index.html's pre-rendered result. If the URL
// hash overrides the defaults, clear the static markup so the user doesn't
// see a stale answer until the VM finishes warming up.
const DEFAULTS = {
  amount: 100,
  fromCurrency: "USD", fromYear: "1990", fromDate: "",
  toCurrency: "USD",   toYear: "2024",   toDate: "",
};

function isDefaultForm(f) {
  return Object.keys(DEFAULTS).every((k) => f[k] === DEFAULTS[k]);
}

initTheme();
readUrl();
readForm();
if (!isDefaultForm(state.form)) renderEmpty("Warming up Ruby VM…");
renderSnippet();
renderHero(null);
refreshRangeHint();
bindCopyButtons();
bindCalcForm();
bindExampleChips();
bootRuby();
