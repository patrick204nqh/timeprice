import { setText } from "./dom.js";
import { state } from "./state.js";

export function renderSnippet() {
  const { amount, from, to, country } = state.form;
  const code = state.snippetMode === "ruby"
    ? `require "timeprice"

Timeprice.inflation(
  amount: ${amount},
  from:   "${from}",
  to:     "${to}",
  country: "${country}",
).amount`
    : `# With a typical inflation API:
require "net/http"
require "json"

# 1. Sign up, get an API key, store it in ENV.
# 2. Add error handling for rate limits, 5xx, timeouts.
# 3. Cache results so you don't burn quota.
# 4. Hope the service is up next year.

uri = URI("https://api.example.com/v1/inflation" \\
          "?amount=${amount}&from=${from}&to=${to}" \\
          "&country=${country}")
req = Net::HTTP::Get.new(uri)
req["Authorization"] = "Bearer #{ENV.fetch('INFLATION_API_KEY')}"

res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
raise "API error #{res.code}" unless res.is_a?(Net::HTTPSuccess)
JSON.parse(res.body).fetch("amount")`;
  setText("#snippet", code);
}
