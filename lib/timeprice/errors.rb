# frozen_string_literal: true

module Timeprice
  class Error < StandardError; end

  class UnsupportedCountry < Error
    attr_reader :country

    def initialize(country)
      @country = country
      super("Unsupported country: #{country.inspect}")
    end
  end

  class UnsupportedCurrency < Error
    attr_reader :currency

    def initialize(currency)
      @currency = currency
      super("Unsupported currency: #{currency.inspect}")
    end
  end

  class DateOutOfRange < Error
    attr_reader :date, :range

    def initialize(date, range)
      @date = date
      @range = range
      super("Date #{date.inspect} out of supported range #{range.inspect}")
    end
  end

  class DataNotFound < Error
    def initialize(message = "Data not found")
      super
    end
  end

  class UnsupportedSchemaVersion < Error
    attr_reader :version, :path

    def initialize(version, path)
      @version = version
      @path = path
      super("Unsupported schema_version #{version.inspect} in #{path}")
    end
  end
end
