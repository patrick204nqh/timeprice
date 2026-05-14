import { state } from "./state.js";

// Metadata lookups shared by view.js, bounds.js, and compute.js. Maps are
// rebuilt by applyMetadata(); before metadata arrives they're empty and
// these helpers return the currency code itself as a stable fallback for
// the brief pre-VM window.

export function countryFor(currency) {
  return state.countryByCurrency.get(currency)?.code || currency;
}

export function countryNameFor(currency) {
  return state.countryByCurrency.get(currency)?.name || currency;
}

// CPI range widest-first: monthly > quarterly > annual. Returns null if the
// country isn't in metadata or has no series.
export function widestCpi(country) {
  if (!country?.cpi) return null;
  return country.cpi.monthly || country.cpi.quarterly || country.cpi.annual || null;
}
