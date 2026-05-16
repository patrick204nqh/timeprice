import { state } from "./state.js";
import { readForm, todayIso } from "./compute.js";
import { renderSnippet, renderHero, renderEmpty } from "./view.js";
import { refreshRangeHint } from "./bounds.js";
import { readUrl } from "./url.js";
import { bindCopyButtons, bindCalcForm, bindExampleChips } from "./events.js";
import { bootRuby } from "./vm.js";
import { initTheme } from "./theme.js";
import { $ } from "./dom.js";
import { bindWhenGroup } from "./when_input.js";

initTheme();

// Default seeding happens before the URL hash is read so a hash override
// can overwrite either side. Both sides land pre-filled — `from` at
// 2008-01-02 (a recognisable historical anchor: first FX-daily weekday of
// the year, well inside every CPI series we ship) and `to` at today.
// First-time visitors see a real computation immediately rather than a
// blank state with a prompt.
// Note: readUrl()/applyPoint() deliberately skips writes for empty dates,
// so a URL like `#to=USD` won't clobber these seeds. Keep that behaviour
// in sync if you change either side.
const fromEl = $("#from-when");
if (fromEl && !fromEl.value) fromEl.value = "2008-01-02";
const toEl = $("#to-when");
if (toEl && !toEl.value) toEl.value = todayIso();

// Bind the Y/M/D widgets *before* readUrl() so applyPoint() finds a setter
// to push values back into. The widgets read the hidden mirror on bind, so
// the seeds above land in the visible fields.
state.whenWidgets = {
  from: bindWhenGroup("from"),
  to: bindWhenGroup("to"),
};

readUrl();
readForm();

// First paint: VM hasn't loaded yet; show the warming-up placeholder. Once
// the VM is ready compute() runs against the seeded form.
renderEmpty();
renderHero(null);

renderSnippet();
refreshRangeHint();
bindCopyButtons();
bindCalcForm();
bindExampleChips();
bootRuby();
