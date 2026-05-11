# frozen_string_literal: true

require_relative "supported"

module Timeprice
  # Base class for every error this library raises. Catch `Timeprice::Error`
  # to handle anything the gem can throw at you.
  class Error < StandardError; end

  # Raised when a country code is not in {Supported::COUNTRIES}.
  class UnsupportedCountry < Error
    attr_reader :country

    def initialize(country)
      @country = country
      super("Unsupported country: #{country.inspect} (supported: #{Supported::COUNTRIES.join(", ")})")
    end
  end

  # Raised when a currency code is not in {Supported::CURRENCIES}.
  class UnsupportedCurrency < Error
    attr_reader :currency

    def initialize(currency)
      @currency = currency
      super("Unsupported currency: #{currency.inspect} (supported: #{Supported::CURRENCIES.join(", ")})")
    end
  end

  # Raised when a requested date falls outside the bundled data range.
  class DateOutOfRange < Error
    attr_reader :date, :range

    def initialize(date, range)
      @date = date
      @range = range
      super("Date #{date.inspect} out of supported range #{range.inspect}")
    end
  end

  # Raised when a CPI or FX lookup has no usable data point.
  class DataNotFound < Error
    def initialize(message = "Data not found")
      super
    end
  end

  # Raised when a bundled data file declares a schema_version this gem
  # doesn't know how to parse (forward-compat guard).
  class UnsupportedSchemaVersion < Error
    attr_reader :version, :path

    def initialize(version, path)
      @version = version
      @path = path
      super("Unsupported schema_version #{version.inspect} in #{path}")
    end
  end
end
