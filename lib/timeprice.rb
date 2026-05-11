# frozen_string_literal: true

require_relative "timeprice/version"
require_relative "timeprice/errors"
require_relative "timeprice/data_loader"
require_relative "timeprice/inflation"
require_relative "timeprice/exchange"
require_relative "timeprice/compare"
require_relative "timeprice/sources"

module Timeprice
  module_function

  def inflation(amount:, from:, to:, country:)
    Inflation.adjust(amount: amount, from: from, to: to, country: country)
  end

  def exchange(amount:, from:, to:, date:)
    Exchange.convert(amount: amount, from: from, to: to, date: date)
  end

  def compare(amount:, from:, to:)
    Compare.run(amount: amount, from: from, to: to)
  end
end
