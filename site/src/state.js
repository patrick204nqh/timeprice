export const state = {
  vm: null,
  metadata: null,
  // Single form covering the merged calculator. fromDate/toDate are only
  // populated when the "Use specific dates" disclosure is open and filled.
  form: {
    amount: 100,
    fromCurrency: "USD", fromYear: "1990", fromDate: "",
    toCurrency: "USD",   toYear: "2024",   toDate: "",
  },
};
