# frozen_string_literal: true

require_relative "namespace"

# KOSIS (Korean Statistical Information Service) monthly CPI — placeholder.
#
# The KOSIS Open API (kosis.kr/openapi/Param/statisticsParameterData.do)
# offers richer Korean CPI breakouts than IMF (regional, group-level) but
# requires per-user API key registration. Until the gem ships with a way to
# accept a KOSIS_API_KEY env var in the update workflow, the gem sources
# Korean monthly CPI from the IMF Data Portal CPI dataflow (KOR.CPI._T.IX.M)
# instead — see tools/data_pipeline/imf.rb.
#
# When KOSIS support is enabled:
#   - Statistic: 통계청 소비자물가지수 (KOSIS stat code DT_1J17104)
#   - Item: total index, monthly, all items
#   - Required params: apiKey, orgId=101, tblId=DT_1J17104, prdSe=M
#   - The CountryFile/MergePolicy chain (kr.json) will then layer KOSIS
#     monthly on top of the World Bank annual baseline, mirroring the
#     Vietnam (WB + IMF) and Japan (e-Stat + WB) patterns.
module Tools
  module DataPipeline
    module KOSIS
      module_function

      def run
        fail NotImplementedError,
             "KOSIS fetcher is not wired up — KR monthly CPI is sourced from " \
             "IMF Data Portal (KOR.CPI._T.IX.M). Remove the KOSIS run.call line " \
             "from tools/data_pipeline/runner.rb, or implement KOSIS_API_KEY support, " \
             "to silence this warning."
      end
    end
  end
end

Tools::DataPipeline::KOSIS.run if __FILE__ == $PROGRAM_NAME
