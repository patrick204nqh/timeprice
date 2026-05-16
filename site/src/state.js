export const state = {
  vm: null,
  metadata: null,
  // Lookup maps rebuilt from metadata.countries on every applyMetadata().
  // O(1) replacements for the array.find() patterns scattered through
  // compute.js. Empty until metadata loads — callers must tolerate misses.
  countryByCode: new Map(),
  countryByCurrency: new Map(),
  // Single form covering the merged calculator. `from` / `to` are free-form
  // date strings — YYYY, YYYY-MM, or YYYY-MM-DD — passed straight to the
  // gem. Empty `to` is coerced to today by compute; empty `from` short-
  // circuits to an empty render.
  form: {
    amount: 100,
    fromCurrency: "USD", from: "",
    toCurrency: "USD",   to: "",
  },
  // Tracks whether the last render reflects a successful Ruby computation.
  // Drives renderSnippet() — copying a `Timeprice.compare(...)` call that
  // would raise in Ruby is a footgun, so we suppress it during invalid form
  // state.
  lastResultValid: false,
  // Bound Y/M/D widget handles, one per side. Populated by app.js at boot.
  // Other modules use these to push assembled date strings back into the
  // visible fields (e.g. url.js applyPoint, metadata.js clampSeed).
  // Contract: set by bindWhenGroup() in app.js; read by url.js, metadata.js, events.js.
  whenWidgets: null,
};
