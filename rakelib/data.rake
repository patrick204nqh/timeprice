# frozen_string_literal: true

namespace :data do
  desc "Refresh CPI and FX data from all sources"
  task :refresh do
    $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
    require "timeprice"
    require_relative "../tools/data_pipeline/runner"
    exit(Tools::DataPipeline::Runner.run)
  end

  desc "Verify the on-disk schema is stable across known fixtures"
  task :check_schema do
    $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
    require "timeprice"
    require_relative "../tools/data_pipeline/schema_check"
    exit(Tools::DataPipeline::SchemaCheck.run)
  end
end
