export const WASM_URL = "./public/timeprice.wasm.gz";

export const CURRENCIES = { US: "USD", UK: "GBP", EU: "EUR", JP: "JPY", VN: "VND" };

// Supported CPI ranges per country (monthly granularity; annual fallback may
// extend earlier, but the <input type="month"> picker only takes months).
export const RANGES = {
  US: { min: "1990-01", max: "2026-03" },
  UK: { min: "1988-01", max: "2026-03" },
  EU: { min: "1996-01", max: "2025-12" },
  JP: { min: "1971-01", max: "2024-12" },
  VN: { min: "2001-12", max: "2026-03" },
};

export const RANGE_LABELS = {
  US: "Jan 1990 – Mar 2026",
  UK: "Jan 1988 – Mar 2026",
  EU: "Jan 1996 – Dec 2025",
  JP: "Jan 1971 – Dec 2024",
  VN: "Dec 2001 – Mar 2026",
};
