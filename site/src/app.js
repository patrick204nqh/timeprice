import { $ } from "./dom.js";
import { readForm, applyRangeForCountry } from "./form.js";
import { renderEmpty } from "./result.js";
import { renderSnippet } from "./snippet.js";
import { readUrl } from "./url.js";
import { bindTabs, bindSnippetToggle, bindCopyButtons, bindForm } from "./events.js";
import { bootRuby } from "./vm.js";

readUrl();
applyRangeForCountry($("#inf-country").value);
readForm();
renderEmpty("Warming up Ruby VM…");
renderSnippet();
bindTabs();
bindSnippetToggle();
bindCopyButtons();
bindForm();
bootRuby();
