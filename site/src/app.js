import { state } from "./state.js";
import { readForm, todayIso } from "./compute.js";
import { renderSnippet, renderHero, renderEmpty } from "./view.js";
import { refreshRangeHint } from "./bounds.js";
import { readUrl } from "./url.js";
import { bindCopyButtons, bindCalcForm, bindExampleChips } from "./events.js";
import { bootRuby } from "./vm.js";
import { initTheme } from "./theme.js";
import { $ } from "./dom.js";

initTheme();

// Default seeding happens before the URL hash is read so a hash override
// can overwrite either side. `to` defaults to today; `from` stays empty
// until the user fills it in — landing on a form that's already half-
// answered makes the historical-side prompt obvious.
const toEl = $("#to-when");
if (toEl && !toEl.value) toEl.value = todayIso();

readUrl();
readForm();

// First paint: empty `from` is the expected default state, so show a
// gentle prompt rather than a stale pre-rendered answer.
renderEmpty("Pick a starting year on the left.");
renderHero(null);

renderSnippet();
refreshRangeHint();
bindCopyButtons();
bindCalcForm();
bindExampleChips();
bootRuby();
