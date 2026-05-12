export const $ = (sel) => document.querySelector(sel);

export const setText = (sel, text) => {
  const el = $(sel);
  if (el) el.textContent = text;
};

export function fmtNumber(n, decimals = 2) {
  return n.toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}
