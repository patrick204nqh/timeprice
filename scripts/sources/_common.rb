# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "date"
require "fileutils"

module Sources
  USER_AGENT = "timeprice-data-fetcher (+https://github.com/patrick204nqh/timeprice)"
  REPO_ROOT  = File.expand_path("../..", __dir__)
  DATA_ROOT  = File.join(REPO_ROOT, "data")

  # CPI `index.base_period`=`base_period` strings can take three observed
  # forms: "1982-1984=100", "2010=100", "2010=100 (rebased 2026-05-11)".
  BASE_YEAR_RE = /\A(?<period>.+?)=100(?:\s*\(rebased\s+(?<rebased>\d{4}-\d{2}-\d{2})\))?\z/

  # Single source of truth for the country↔currency mapping used by the
  # manifest writer and the v2→v3 migration script. Adding a country = add
  # it here (and ship a CPI file for it).
  COUNTRY_TO_CURRENCY = {
    "US" => "USD",
    "UK" => "GBP",
    "EU" => "EUR",
    "JP" => "JPY",
    "VN" => "VND",
  }.freeze

  module_function

  # Perform an HTTP GET (or POST when body given) with one retry on transient errors.
  def http_request(url, method: :get, body: nil, headers: {}, timeout: 30)
    uri = URI.parse(url)
    last_error = nil
    2.times do |attempt|
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                          open_timeout: timeout, read_timeout: timeout) do |http|
        req = case method
              when :post
                Net::HTTP::Post.new(uri.request_uri)
              else
                Net::HTTP::Get.new(uri.request_uri)
              end
        req["User-Agent"] = USER_AGENT
        req["Accept"] = headers["Accept"] || "application/json"
        headers.each { |k, v| req[k] = v }
        if body
          req["Content-Type"] ||= "application/json"
          req.body = body.is_a?(String) ? body : JSON.generate(body)
        end
        res = http.request(req)
        raise "HTTP #{res.code} for #{url}: #{res.body.to_s[0, 200]}" unless res.is_a?(Net::HTTPSuccess)

        return res.body
      end
    rescue StandardError => e
      last_error = e
      sleep(2) if attempt.zero?
    end
    raise last_error
  end

  def http_json(url, **)
    JSON.parse(http_request(url, **))
  end

  def write_json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{JSON.pretty_generate(deep_sort(data))}\n")
  end

  def read_json_if_exists(path)
    return nil unless File.exist?(path)

    JSON.parse(File.read(path))
  end

  # Recursively sort hash keys; preserve array order (deterministic output).
  def deep_sort(obj)
    case obj
    when Hash
      obj.keys.map(&:to_s).sort.to_h { |k| [k, deep_sort(obj[k] || obj[k.to_sym])] }
    when Array
      obj.map { |v| deep_sort(v) }
    else
      obj
    end
  end

  def today
    Date.today.iso8601
  end

  # CPI drift detector. Returns [:ok | :rebase | :reject, ratio_or_nil, msg]
  # Compares shared keys between prior and incoming hash<period, value>.
  def cpi_drift_check(prior_series, new_series)
    return [:ok, nil, "no prior"] if prior_series.nil? || prior_series.empty?

    shared = prior_series.keys & new_series.keys
    return [:ok, nil, "no shared"] if shared.empty?

    drifts = shared.map do |k|
      old_v = prior_series[k].to_f
      new_v = new_series[k].to_f
      next nil if old_v.zero?

      [k, (new_v - old_v).abs / old_v]
    end.compact
    return [:ok, nil, "no comparable"] if drifts.empty?

    max_key, max_drift = drifts.max_by { |_, d| d }
    if max_drift > 0.005
      # >0.5%: probable rebase. Compute renormalization ratio at median shared.
      ratios = shared.map do |k|
        nv = new_series[k].to_f
        ov = prior_series[k].to_f
        next nil if ov.zero?

        nv / ov
      end.compact.sort
      med = ratios[ratios.length / 2]
      # Stable, grep-able marker for the CI auto-merge gate (PLAN.md §9.4).
      log "REBASE: max drift #{(max_drift * 100).round(3)}% at #{max_key} (ratio≈#{med.round(4)})"
      [:rebase, med, "max drift #{(max_drift * 100).round(3)}% at #{max_key} (likely rebase, ratio≈#{med.round(4)})"]
    else
      if max_drift > 0.001
        # Below rebase threshold but above routine-update noise floor.
        log "DRIFT WARNING: max drift #{(max_drift * 100).round(4)}% at #{max_key}"
      end
      [:ok, max_drift, "max drift #{(max_drift * 100).round(4)}% at #{max_key}"]
    end
  end

  # Renormalize a hash of period=>value by ratio. Returns new hash.
  def renormalize(series, ratio)
    series.transform_values { |v| (v.to_f * ratio).round(6) }
  end

  def validate_positive_numeric!(hash, label)
    hash.each do |k, v|
      raise "#{label}: non-numeric value at #{k}: #{v.inspect}" unless v.is_a?(Numeric)
      raise "#{label}: non-positive value at #{k}: #{v}" unless v.positive?
    end
  end

  def log(msg)
    puts msg
  end
end
