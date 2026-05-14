import { WASM_URL, WASM_META_URL } from "./data.js";
import { $, setText } from "./dom.js";
import { state } from "./state.js";
import { compute, renderError, refreshRangeHint, refreshDateBounds, refreshYearBounds } from "./compute.js";
import { loadMetadata, applyMetadata } from "./metadata.js";
import { loadCachedModule, saveCachedModule } from "./wasm_cache.js";

export function setVmState(state_, label, dotClass) {
  setText("#vm-label", label);
  const dot = $("#vm-dot");
  dot.className = `inline-block w-2 h-2 rounded-full ${dotClass}`;
  $("#vm-pill").dataset.state = state_;
}

async function fetchSha() {
  // Cache key for the compiled module. If the meta fetch fails, we fall
  // through to a fresh compile without caching — correctness over speed.
  try {
    const res = await fetch(WASM_META_URL, { cache: "no-cache" });
    if (!res.ok) return null;
    const { sha256 } = await res.json();
    return typeof sha256 === "string" ? sha256 : null;
  } catch {
    return null;
  }
}

async function compileWasm() {
  const response = await fetch(WASM_URL);
  if (!response.ok) throw new Error(`HTTP ${response.status} fetching wasm`);
  const decompressed = response.body.pipeThrough(new DecompressionStream("gzip"));
  return WebAssembly.compileStreaming(new Response(decompressed, {
    headers: { "Content-Type": "application/wasm" },
  }));
}

export async function bootRuby() {
  try {
    // Loader import and meta.json fetch are independent — start both in
    // parallel so cold-load latency is `max(loader, sha)` not `sum`.
    const loaderPromise = import("https://cdn.jsdelivr.net/npm/@ruby/wasm-wasi@2/dist/browser/+esm");
    const sha = await fetchSha();
    let module = sha ? await loadCachedModule(sha) : null;
    if (!module) {
      module = await compileWasm();
      if (sha) saveCachedModule(sha, module);
    }
    const { DefaultRubyVM } = await loaderPromise;
    const { vm } = await DefaultRubyVM(module);
    vm.eval(`require "/bundle/setup"`);
    state.vm = vm;
    if (loadMetadata()) applyMetadata();
    refreshRangeHint();
    refreshDateBounds();
    refreshYearBounds();
    setVmState("ready", "Live · running in your browser", "bg-emerald-500");
    compute();
  } catch (e) {
    console.error(e);
    setVmState("error", "Ruby VM failed to load — see console", "bg-rose-500");
    renderError("Ruby VM failed to load. Check your browser console.");
  }
}
