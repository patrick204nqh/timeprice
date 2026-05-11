# Data Licenses & Attribution

`timeprice` redistributes data from several public statistical agencies. The
gem's own **code** is MIT-licensed (see `LICENSE.txt`); the **data** under
`data/` is governed by the licenses below. If you redistribute results derived
from this gem in a product or publication, reproduce the relevant attribution
string.

| Source | Series | License / Terms | License URL | Attribution string |
|--------|--------|----------------|-------------|--------------------|
| U.S. Bureau of Labor Statistics | CPI-U `CUUR0000SA0` (US CPI) | U.S. Government work — public domain. BLS asks (does not require) that BLS be cited as the source. | https://www.bls.gov/bls/linksite.htm | Data: U.S. Bureau of Labor Statistics |
| UK Office for National Statistics | `D7BT` (UK CPI all-items) | Open Government Licence v3.0 | https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/ | Contains public sector information licensed under the Open Government Licence v3.0 |
| Eurostat | `prc_hicp_midx` (Euro area HICP) | Eurostat reuse policy — free reuse with source attribution | https://ec.europa.eu/eurostat/about-us/policies/copyright | Source: Eurostat |
| World Bank | `FP.CPI.TOTL` (JP CPI fallback) | Creative Commons Attribution 4.0 International (CC BY 4.0) | https://datacatalog.worldbank.org/public-licenses#cc-by | Source: World Bank, FP.CPI.TOTL |
| World Bank | `FP.CPI.TOTL` (VN CPI, annual fallback) | Creative Commons Attribution 4.0 International (CC BY 4.0) | https://datacatalog.worldbank.org/public-licenses#cc-by | Source: World Bank, FP.CPI.TOTL |
| International Monetary Fund | CPI dataflow `VNM.CPI._T.IX.M` via IMF Data Portal (VN CPI, monthly primary) | Free reuse with attribution per IMF terms | https://www.imf.org/external/terms.htm | Source: IMF Data Portal CPI dataflow |
| European Central Bank (via Frankfurter) | Daily reference rates, USD base, EUR/GBP/JPY/AUD/CAD/KRW/CNY | ECB reference rates — free reuse; Frankfurter is a non-commercial republisher with no separate license | https://www.ecb.europa.eu/services/disclaimer/html/index.en.html | FX data: European Central Bank reference rates via Frankfurter |
| World Bank | `PA.NUS.FCRF` (VND annual average FX, broadcast daily) | Creative Commons Attribution 4.0 International (CC BY 4.0) | https://datacatalog.worldbank.org/public-licenses#cc-by | VND FX: World Bank, PA.NUS.FCRF |
| Australian Bureau of Statistics | `CPI` dataflow, key `3.10001.10.50.Q` (AU CPI, quarterly, all groups, weighted average of eight capital cities) | Creative Commons Attribution 4.0 International (CC BY 4.0) | https://www.abs.gov.au/website-privacy-copyright-and-disclaimer/copyright-and-creative-commons | Source: Australian Bureau of Statistics, 6401.0 Consumer Price Index |
| Statistics Canada | Table 18-10-0004-01, vector `v41690973` (CA CPI, monthly, all-items, not seasonally adjusted) | Statistics Canada Open License | https://www.statcan.gc.ca/en/reference/licence | Source: Statistics Canada, table 18-10-0004-01 |
| International Monetary Fund | CPI dataflow `KOR.CPI._T.IX.M` (KR CPI, monthly) | Free reuse with attribution per IMF terms | https://www.imf.org/external/terms.htm | Source: IMF Data Portal CPI dataflow |
| International Monetary Fund | CPI dataflow `CHN.CPI._T.IX.M` (CN CPI, monthly) | Free reuse with attribution per IMF terms | https://www.imf.org/external/terms.htm | Source: IMF Data Portal CPI dataflow |
| International Monetary Fund | CPI dataflow `RUS.CPI._T.IX.M` (RU CPI, monthly) | Free reuse with attribution per IMF terms | https://www.imf.org/external/terms.htm | Source: IMF Data Portal CPI dataflow |
| International Monetary Fund | IFS dataflow `M.RUS.ENDA_XDC_USD_RATE` (RUB/USD, period-average, annual mean written to `_annual.json`) | Free reuse with attribution per IMF terms | https://www.imf.org/external/terms.htm | Source: IMF International Financial Statistics |
| World Bank | `FP.CPI.TOTL` (AU/CA/KR/CN/RU CPI annual baselines) | Creative Commons Attribution 4.0 International (CC BY 4.0) | https://datacatalog.worldbank.org/public-licenses#cc-by | Source: World Bank, FP.CPI.TOTL |

## Notes

- License URLs were last reviewed against published text at the time of v0.1.0.
  Terms drift; if you have a stricter compliance requirement, re-check directly
  with the publisher.
- The Vietnam VND FX series is the **annual average** broadcast to every day in
  the year — it is intentionally not a daily market rate. Do not use it for
  intraday or trade-execution purposes.
- **RUB FX is annual-only** (from IMF IFS period averages). Frankfurter (ECB)
  stopped publishing RUB daily reference rates in March 2022 after the ECB
  suspended the rate, and no other free, no-API-key daily source covers the
  full series. Daily RUB lookups fall back to the annual average and the
  result is tagged so consumers can detect the degradation.
- **AU CPI is published quarterly only.** Lookups against "YYYY-MM" keys for
  Australia fall back to the quarter that contains the month, and the result
  is tagged `:monthly_from_quarterly_fallback`.
- Eurostat HICP is harmonized across the Eurozone and is **not** the same as
  any national CPI. We use it for the `EU` country code; national CPIs are out
  of scope for v0.1.
- `timeprice sources` (CLI) prints these attribution strings plus the current
  bundled coverage at runtime — useful for downstream-product compliance.
