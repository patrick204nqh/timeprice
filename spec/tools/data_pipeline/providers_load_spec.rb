# frozen_string_literal: true

require "timeprice"
$LOAD_PATH.unshift(File.expand_path("../../../tools/data_pipeline", __dir__))

require "namespace"
require "provider"
require "bls"
require "ons"
require "eurostat"
require "imf"
require "abs"
require "statcan"
require "world_bank"
require "frankfurter"

RSpec.describe "data pipeline providers" do
  it "registers every expected country with a non-empty currency mapping" do
    codes = Tools::DataPipeline::Provider.registry.map(&:country_code).map(&:upcase).uniq.sort
    map   = Tools::DataPipeline::COUNTRY_TO_CURRENCY.keys.sort
    missing = codes - map
    expect(missing).to be_empty, "providers without COUNTRY_TO_CURRENCY entry: #{missing.inspect}"
  end

  it "assigns a unique (country, provider_id) pair per registered provider" do
    seen = {}
    Tools::DataPipeline::Provider.registry.each do |klass|
      key = [klass.country_code, klass.provider_id]
      expect(seen).not_to have_key(key), "duplicate provider: #{key.inspect}"
      seen[key] = klass
    end
  end

  it "exposes a #fetch instance method on every registered provider" do
    Tools::DataPipeline::Provider.registry.each do |klass|
      expect(klass.instance_method(:fetch)).to be_a(UnboundMethod), "#{klass} missing #fetch"
    end
  end
end
