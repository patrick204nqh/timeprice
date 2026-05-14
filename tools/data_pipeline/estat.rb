# frozen_string_literal: true

require_relative "namespace"

require_relative "_common"
require_relative "world_bank"

# Japan CPI from e-Stat (Statistics Bureau of Japan).
#
# Per PLAN §7: e-Stat registration friction is real; an API key is required
# and English docs are thin. Falls back to World Bank FP.CPI.TOTL (annual)
# if ESTAT_APP_ID is unset. The fallback is explicitly endorsed by the plan.
module Tools
  module DataPipeline
    module EStat
      module_function

      def run
        app_id = ENV.fetch("ESTAT_APP_ID", nil)
        if app_id.nil? || app_id.empty?
          Tools::DataPipeline.log "e-Stat: ESTAT_APP_ID not set — falling back to World Bank annual CPI for Japan (per PLAN §7)."
          Tools::DataPipeline::WorldBank.run_jp_cpi_fallback
          return
        end
        # If a key IS available, attempt the real fetch. We deliberately keep this
        # branch minimal and resilient: failure here falls back to World Bank.
        begin
          fetch_with_key(app_id)
        rescue StandardError => e
          Tools::DataPipeline.log "e-Stat: real fetch failed (#{e.class}: #{e.message}) — falling back to World Bank."
          Tools::DataPipeline::WorldBank.run_jp_cpi_fallback
        end
      end

      # Placeholder real fetch. JP CPI series IDs vary; absent docs verification
      # in this offline run, we raise so the rescue path falls back cleanly.
      def fetch_with_key(_app_id)
        fail NotImplementedError, "e-Stat real fetch not implemented in v0.1; using World Bank fallback."
      end
    end
  end
end

Tools::DataPipeline::EStat.run if __FILE__ == $PROGRAM_NAME
