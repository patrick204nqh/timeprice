# frozen_string_literal: true

require "json"

module Timeprice
  # Frozen value object describing the bundled dataset: version, refresh
  # date, country list with CPI ranges, currency list with display names,
  # and FX coverage. Replaces the previous Hash return shape on
  # {Timeprice.metadata}.
  #
  # `[]`, `to_h`, and `to_json` are kept compatible with the old Hash
  # interface so downstream consumers (the website, this gem's specs)
  # don't need a coordinated rewrite.
  MetadataSnapshot = Data.define(:version, :generated_at, :countries, :currencies, :fx) do
    def [](key)
      to_h[key]
    end

    def to_json(*args)
      to_h.to_json(*args)
    end
  end
end
