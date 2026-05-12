// ---------- constants ----------

const WASM_URL = "./public/timeprice.wasm.gz";

const CURRENCIES = { US: "USD", UK: "GBP", EU: "EUR", JP: "JPY", VN: "VND" };

// Supported CPI ranges per country (monthly granularity; annual fallback may
// extend earlier, but the <input type="month"> picker only takes months).
const RANGES = {
  US: { min: "1990-01", max: "2026-03" },
  UK: { min: "1988-01", max: "2026-03" },
  EU: { min: "1996-01", max: "2025-12" },
  JP: { min: "1971-01", max: "2024-12" },
  VN: { min: "2001-12", max: "2026-03" },
};

const RANGE_LABELS = {
  US: "Jan 1990 – Mar 2026",
  UK: "Jan 1988 – Mar 2026",
  EU: "Jan 1996 – Dec 2025",
  JP: "Jan 1971 – Dec 2024",
  VN: "Dec 2001 – Mar 2026",
};

// ---------- state ----------

const state = {
  vm: null,
  snippetMode: "ruby",
  tab: "inflation",
  form: { amount: 100, from: "1990-01", to: "2024-01", country: "US" },
};

// ---------- dom helpers ----------

const $ = (sel) => document.querySelector(sel);
const setText = (sel, text) => { const el = $(sel); if (el) el.textContent = text; };

// ---------- utils ----------

function currencyFor(country) {
  return CURRENCIES[country] || "USD";
}

function fmtNumber(n, decimals = 2) {
  return n.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
}

function cleanErrorMessage(e) {
  const raw = (e && e.message) ? String(e.message) : String(e);
  const firstLine = raw.split("\n")[0].trim();
  return firstLine.replace(/^Error:\s*/, "") || "Calculation failed.";
}

// ---------- form ----------

function readForm() {
  state.form = {
    amount: parseFloat($("#inf-amount").value) || 0,
    from:   $("#inf-from").value,
    to:     $("#inf-to").value,
    country: $("#inf-country").value,
  };
}

function clampMonth(value, country) {
  const r = RANGES[country];
  if (!r || !value) return value;
  if (value < r.min) return r.min;
  if (value > r.max) return r.max;
  return value;
}

function applyRangeForCountry(country) {
  const r = RANGES[country];
  if (!r) return;
  for (const sel of ["#inf-from", "#inf-to"]) {
    const el = $(sel);
    el.min = r.min;
    el.max = r.max;
    const clamped = clampMonth(el.value, country);
    if (clamped !== el.value) el.value = clamped;
  }
  setText("#inf-range-hint", `Data available: ${RANGE_LABELS[country]}`);
}

function validateRange(from, to, country) {
  const r = RANGES[country];
  if (!r) return null;
  const [minLabel, maxLabel] = RANGE_LABELS[country].split(" – ");
  if (from < r.min || to < r.min) return `${country} CPI data starts ${minLabel}.`;
  if (from > r.max || to > r.max) return `${country} CPI data ends ${maxLabel}.`;
  return null;
}

// ---------- result ----------

function renderResult(result, country) {
  const cur = currencyFor(country);
  setText("#inf-amount-out", `${fmtNumber(result.amount)} ${cur}`);
  setText("#inf-detail", `${fmtNumber(result.original_amount)} ${cur} (${result.from}) → ${fmtNumber(result.amount)} ${cur} (${result.to})`);
  setText("#inf-meta", `CPI ${result.from_index} → ${result.to_index} · ${result.country} · ${result.granularity}`);
}

function renderEmpty(message = "Press Calculate once the Ruby VM is ready.") {
  setText("#inf-amount-out", "—");
  setText("#inf-detail", message);
  setText("#inf-meta", "");
}

function renderError(message) {
  setText("#inf-amount-out", "—");
  setText("#inf-detail", message);
  setText("#inf-meta", "");
}

// ---------- snippet ----------

function renderSnippet() {
  const { amount, from, to, country } = state.form;
  const code = state.snippetMode === "ruby"
    ? `require "timeprice"

Timeprice.inflation(
  amount: ${amount},
  from:   "${from}",
  to:     "${to}",
  country: "${country}",
).amount`
    : `# With a typical inflation API:
require "net/http"
require "json"

# 1. Sign up, get an API key, store it in ENV.
# 2. Add error handling for rate limits, 5xx, timeouts.
# 3. Cache results so you don't burn quota.
# 4. Hope the service is up next year.

uri = URI("https://api.example.com/v1/inflation" \\
          "?amount=${amount}&from=${from}&to=${to}" \\
          "&country=${country}")
req = Net::HTTP::Get.new(uri)
req["Authorization"] = "Bearer #{ENV.fetch('INFLATION_API_KEY')}"

res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
raise "API error #{res.code}" unless res.is_a?(Net::HTTPSuccess)
JSON.parse(res.body).fetch("amount")`;
  setText("#snippet", code);
}

// ---------- calculate ----------

async function calculate() {
  if (!state.vm) return;
  readForm();
  const { amount, from, to, country } = state.form;

  const rangeErr = validateRange(from, to, country);
  if (rangeErr) {
    renderError(rangeErr);
    return;
  }

  const btn = $("#inf-calc");
  btn.disabled = true;
  const origLabel = btn.textContent;
  btn.textContent = "Calculating…";

  try {
    const rb = state.vm.eval(`
      require "timeprice"
      r = Timeprice.inflation(amount: ${amount}, from: "${from}", to: "${to}", country: "${country}")
      JSON.generate(r.to_h)
    `);
    const result = JSON.parse(rb.toString());
    renderResult(result, country);
  } catch (e) {
    console.error(e);
    renderError(cleanErrorMessage(e));
  } finally {
    btn.disabled = false;
    btn.textContent = origLabel;
  }
}

// ---------- url ----------

function readUrl() {
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

function writeUrl() {
  if (state.tab !== "inflation") {
    history.replaceState(null, "", `#${state.tab}`);
    return;
  }
  const { amount, from, to, country } = state.form;
  history.replaceState(null, "", `#inflation/${country}/${amount}/${from}/${to}`);
}

// ---------- events ----------

function bindTabs() {
  for (const t of document.querySelectorAll(".tab")) {
    t.addEventListener("click", (e) => {
      if (t.getAttribute("aria-disabled") === "true") { e.preventDefault(); return; }
      const name = t.dataset.tab;
      state.tab = name;
      document.querySelectorAll(".tab").forEach(el => {
        const sel = el.dataset.tab === name;
        el.setAttribute("aria-selected", sel);
        el.classList.toggle("bg-stone-200", sel);
        el.classList.toggle("dark:bg-stone-800", sel);
        if (el.getAttribute("aria-disabled") !== "true") {
          el.classList.toggle("text-stone-500", !sel);
        }
      });
      document.querySelectorAll(".panel").forEach(p => {
        p.classList.toggle("hidden", p.dataset.panel !== name);
      });
      writeUrl();
    });
  }
  // initial selected style
  document.querySelector('.tab[data-tab="inflation"]').classList.add("bg-stone-200", "dark:bg-stone-800");
}

function bindSnippetToggle() {
  for (const b of document.querySelectorAll(".snip-toggle")) {
    b.addEventListener("click", () => {
      state.snippetMode = b.dataset.snippet;
      document.querySelectorAll(".snip-toggle").forEach(el => {
        const sel = el.dataset.snippet === state.snippetMode;
        el.setAttribute("aria-selected", sel);
        el.classList.toggle("bg-stone-200", sel);
        el.classList.toggle("dark:bg-stone-800", sel);
        el.classList.toggle("text-stone-500", !sel);
      });
      renderSnippet();
    });
  }
  document.querySelector('.snip-toggle[data-snippet="ruby"]').classList.add("bg-stone-200", "dark:bg-stone-800");
}

function bindCopyButtons() {
  document.body.addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-copy], #snip-copy");
    if (!btn) return;
    const text = btn.dataset.copy || $("#snippet").textContent;
    try { await navigator.clipboard.writeText(text); } catch {}
    if (!btn.dataset.origText) btn.dataset.origText = btn.textContent;
    btn.textContent = "copied";
    setTimeout(() => { btn.textContent = btn.dataset.origText; }, 1200);
  });
}

function bindForm() {
  const inputs = ["#inf-amount", "#inf-from", "#inf-to"];
  for (const sel of inputs) {
    $(sel).addEventListener("input", () => {
      readForm();
      renderSnippet();
      writeUrl();
    });
  }
  $("#inf-country").addEventListener("change", () => {
    applyRangeForCountry($("#inf-country").value);
    readForm();
    renderSnippet();
    writeUrl();
  });
  $("#inf-form").addEventListener("submit", (e) => {
    e.preventDefault();
    calculate();
  });
}

// ---------- vm ----------

function setVmState(state_, label, dotClass) {
  setText("#vm-label", label);
  const dot = $("#vm-dot");
  dot.className = `inline-block w-2 h-2 rounded-full ${dotClass}`;
  $("#vm-pill").dataset.state = state_;
}

async function bootRuby() {
  try {
    const { DefaultRubyVM } = await import("https://cdn.jsdelivr.net/npm/@ruby/wasm-wasi@2/dist/browser/+esm");
    const response = await fetch(WASM_URL);
    if (!response.ok) throw new Error(`HTTP ${response.status} fetching wasm`);
    const decompressed = response.body.pipeThrough(new DecompressionStream("gzip"));
    const module = await WebAssembly.compileStreaming(new Response(decompressed, {
      headers: { "Content-Type": "application/wasm" },
    }));
    const { vm } = await DefaultRubyVM(module);
    vm.eval(`require "/bundle/setup"`);
    state.vm = vm;
    setVmState("ready", "Live · running in your browser", "bg-emerald-500");
    $("#inf-calc").disabled = false;
    calculate();
  } catch (e) {
    console.error(e);
    setVmState("error", "Ruby VM failed to load — see console", "bg-rose-500");
    renderError("Ruby VM failed to load. Check your browser console.");
  }
}

// ---------- boot ----------

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
