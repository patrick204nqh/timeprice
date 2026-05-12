import { WASM_URL } from "./data.js";
import { $, setText } from "./dom.js";
import { state } from "./state.js";
import { calculate } from "./calculate.js";
import { runFx } from "./fx.js";
import { runCompare } from "./compare.js";
import { renderError } from "./result.js";

export function setVmState(state_, label, dotClass) {
  setText("#vm-label", label);
  const dot = $("#vm-dot");
  dot.className = `inline-block w-2 h-2 rounded-full ${dotClass}`;
  $("#vm-pill").dataset.state = state_;
}

export async function bootRuby() {
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
    calculate();
    runFx();
    runCompare();
  } catch (e) {
    console.error(e);
    setVmState("error", "Ruby VM failed to load — see console", "bg-rose-500");
    renderError("Ruby VM failed to load. Check your browser console.");
  }
}
