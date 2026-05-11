# frozen_string_literal: true

# Point DataLoader at the bundled test fixtures BEFORE requiring the library,
# so any constant resolution sees the override.
ENV["TIMEPRICE_DATA_ROOT"] ||= File.expand_path("fixtures", __dir__)

require "timeprice"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Timeprice::DataLoader.clear_cache!
  end
end
