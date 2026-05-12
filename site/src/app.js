const WASM_URL = "./public/timeprice.wasm.gz";

const $ = (sel) => document.querySelector(sel);

const state = {
  vm: null,
  snippetMode: "ruby",
  tab: "inflation",
  form: { amount: 100, from: "1990-01", to: "2024-01", country: "US" },
};

function readForm() {
  state.form = {
    amount: parseFloat($("#inf-amount").value) || 0,
    from:   $("#inf-from").value,
    to:     $("#inf-to").value,
    country: $("#inf-country").value,
  };
}

function currencyFor(country) {
  return { US: "USD", UK: "GBP", EU: "EUR", JP: "JPY", VN: "VND" }[country] || "USD";
}

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
  $("#snippet").textContent = code;
}

function setVmState(state_, label, dotClass) {
  $("#vm-label").textContent = label;
  const dot = $("#vm-dot");
  dot.className = `inline-block w-2 h-2 rounded-full ${dotClass}`;
  $("#vm-pill").dataset.state = state_;
}

function fmtNumber(n, decimals = 2) {
  return n.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
}

async function calculate() {
  if (!state.vm) return;
  readForm();
  const { amount, from, to, country } = state.form;
  const btn = $("#inf-calc");
  btn.disabled = true;
  btn.textContent = "Calculating…";

  try {
    const rb = state.vm.eval(`
      require "timeprice"
      r = Timeprice.inflation(amount: ${amount}, from: "${from}", to: "${to}", country: "${country}")
      JSON.generate(r.to_h)
    `);
    const result = JSON.parse(rb.toString());
    const cur = currencyFor(country);
    $("#inf-amount-out").textContent = `${fmtNumber(result.amount)} ${cur}`;
    $("#inf-detail").textContent     = `${fmtNumber(result.original_amount)} ${cur} (${result.from}) → ${fmtNumber(result.amount)} ${cur} (${result.to})`;
    $("#inf-meta").textContent       = `CPI ${result.from_index} → ${result.to_index} · ${result.country} · ${result.granularity}`;
  } catch (e) {
    $("#inf-amount-out").textContent = "—";
    $("#inf-detail").textContent     = e.message || "Calculation failed.";
    $("#inf-meta").textContent       = "";
  } finally {
    btn.disabled = false;
    btn.textContent = "Calculate";
  }
}

function bindTabs() {
  for (const t of document.querySelectorAll(".tab")) {
    t.addEventListener("click", () => {
      const name = t.dataset.tab;
      state.tab = name;
      document.querySelectorAll(".tab").forEach(el => {
        const sel = el.dataset.tab === name;
        el.setAttribute("aria-selected", sel);
        el.classList.toggle("bg-stone-200", sel);
        el.classList.toggle("dark:bg-stone-800", sel);
        el.classList.toggle("text-stone-500", !sel);
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
    const orig = btn.textContent;
    btn.textContent = "copied";
    setTimeout(() => { btn.textContent = orig; }, 1200);
  });
}

function bindForm() {
  const inputs = ["#inf-amount", "#inf-from", "#inf-to", "#inf-country"];
  for (const sel of inputs) {
    $(sel).addEventListener("input", () => {
      readForm();
      renderSnippet();
      writeUrl();
    });
  }
  $("#inf-form").addEventListener("submit", (e) => {
    e.preventDefault();
    calculate();
  });
}

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
  } catch (e) {
    console.error(e);
    setVmState("error", "Ruby VM failed to load — see console", "bg-rose-500");
  }
}

readUrl();
renderSnippet();
bindTabs();
bindSnippetToggle();
bindCopyButtons();
bindForm();
bootRuby();
