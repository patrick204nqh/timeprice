export const WASM_URL = "./public/timeprice.wasm.gz";

// Display symbols for currencies used in the hero. Pure presentation data
// (not in the gem's domain), so it stays here.
export const CURRENCY_SYMBOLS = { USD: "$", GBP: "£", EUR: "€", JPY: "¥", VND: "₫", AUD: "A$", CAD: "C$", CNY: "¥", KRW: "₩", RUB: "₽" };

// Pre-VM fallback used until Timeprice.metadata loads. The site needs *something*
// to show in the first ~1 second before the wasm boots. Once metadata arrives,
// these values are replaced — they're a courtesy, not the source of truth.
export const FALLBACK_COUNTRY_CURRENCY = { US: "USD", UK: "GBP", EU: "EUR", JP: "JPY", VN: "VND" };

import { state } from "./state.js";

export function currencyFor(country) {
  const fromMeta = state.metadata?.countries?.find((c) => c.code === country)?.currency;
  return fromMeta || FALLBACK_COUNTRY_CURRENCY[country] || "USD";
}
