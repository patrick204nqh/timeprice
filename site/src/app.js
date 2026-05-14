import { state } from "./state.js";
import { readForm } from "./compute.js";
import { renderSnippet, renderHero, renderEmpty } from "./view.js";
import { refreshRangeHint, refreshYearBounds } from "./bounds.js";
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
// Default form matches the pre-rendered HTML — leave it alone so the user
// sees a real answer on first paint instead of placeholder dots. Any URL
// override clears both the result block AND the hero so they don't show
// the stale defaults next to a fresh "From" value.
if (!isDefaultForm(state.form)) {
  renderEmpty("Warming up Ruby VM…");
  renderHero(null);
}
renderSnippet();
refreshRangeHint();
refreshYearBounds();
bindCopyButtons();
bindCalcForm();
bindExampleChips();
bootRuby();
