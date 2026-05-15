export const state = {
  vm: null,
  metadata: null,
  // Lookup maps rebuilt from metadata.countries on every applyMetadata().
  // O(1) replacements for the array.find() patterns scattered through
  // compute.js. Empty until metadata loads — callers must tolerate misses.
  countryByCode: new Map(),
  countryByCurrency: new Map(),
  // Single form covering the merged calculator. fromDate/toDate are only
  // populated when the "Use specific dates" disclosure is open and filled.
  form: {
    amount: 100,
    fromCurrency: "USD", fromYear: "1990", fromDate: "",
    toCurrency: "USD",   toYear: "2024",   toDate: "",
  },
  // Tracks whether the last render reflects a successful Ruby computation.
  // Drives renderSnippet() — copying a `Timeprice.compare(...)` call that
  // would raise in Ruby is a footgun, so we suppress it during invalid form
  // state.
  lastResultValid: false,
};
