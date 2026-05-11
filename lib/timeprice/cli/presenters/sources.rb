# frozen_string_literal: true

module Timeprice
  class CLI < Thor
    module Presenters
      # Renders the sources list in compact-table, verbose, and JSON formats.
      class Sources
        MAX_SOURCE_NAME = 60

        def initialize(list, verbose: false)
          @list = list
          @verbose = verbose
        end

        def json_hash
          @list
        end

        def text_lines
          @verbose ? verbose_lines : table_lines
        end

        private

        def table_lines
          rows = @list.map do |s|
            [s[:id].to_s, short_source_name(s[:name]), s[:license].to_s, s[:coverage].to_s]
          end
          headers = %w[ID SOURCE LICENSE COVERAGE]
          widths = headers.each_with_index.map { |h, i| [h.length, *rows.map { |r| r[i].length }].max }
          fmt = "  %-#{widths[0]}s  %-#{widths[1]}s  %-#{widths[2]}s  %s"
          [
            format(fmt, *headers),
            *rows.map { |r| format(fmt, *r) },
            "",
            "Run `timeprice sources --verbose` for license URLs and full attribution.",
          ]
        end

        def verbose_lines
          @list.flat_map do |s|
            [
              s[:name].to_s,
              "  id:           #{s[:id]}",
              "  license:      #{s[:license]}",
              "  license_url:  #{s[:license_url]}",
              "  attribution:  #{s[:attribution]}",
              "  coverage:     #{s[:coverage]}",
              "",
            ]
          end
        end

        # Cap the source-name column width. Truncation is last resort — the full
        # name (with series code) is preserved in `--verbose` output.
        def short_source_name(name)
          s = name.to_s
          return s if s.length <= MAX_SOURCE_NAME

          "#{s[0, MAX_SOURCE_NAME - 1]}…"
        end
      end
    end
  end
end
