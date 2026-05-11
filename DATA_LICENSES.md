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
| International Monetary Fund | `PCPI_IX` IFS series (VN CPI, monthly primary) | Free reuse with attribution per IMF terms | https://www.imf.org/external/terms.htm | Source: IMF International Financial Statistics |
| European Central Bank (via Frankfurter) | Daily reference rates, USD base, EUR/GBP/JPY | ECB reference rates — free reuse; Frankfurter is a non-commercial republisher with no separate license | https://www.ecb.europa.eu/services/disclaimer/html/index.en.html | FX data: European Central Bank reference rates via Frankfurter |
| World Bank | `PA.NUS.FCRF` (VND annual average FX, broadcast daily) | Creative Commons Attribution 4.0 International (CC BY 4.0) | https://datacatalog.worldbank.org/public-licenses#cc-by | VND FX: World Bank, PA.NUS.FCRF |

## Notes

- License URLs were last reviewed against published text at the time of v0.1.0.
  Terms drift; if you have a stricter compliance requirement, re-check directly
  with the publisher.
- The Vietnam VND FX series is the **annual average** broadcast to every day in
  the year — it is intentionally not a daily market rate. Do not use it for
  intraday or trade-execution purposes.
- Eurostat HICP is harmonized across the Eurozone and is **not** the same as
  any national CPI. We use it for the `EU` country code; national CPIs are out
  of scope for v0.1.
- `timeprice sources` (CLI) prints these attribution strings plus the current
  bundled coverage at runtime — useful for downstream-product compliance.
