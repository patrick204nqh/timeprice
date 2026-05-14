# frozen_string_literal: true

require_relative "namespace"

module Tools
  module DataPipeline
    # Base class for all pipeline-specific errors. Catching this in the
    # runner lets the orchestrator separate "the wire told us something
    # wrong" from "Ruby blew up unexpectedly".
    class Error < StandardError; end

    # An HTTP request returned a non-2xx status. The runner can choose to
    # retry on transient (5xx) errors and bail out on permanent (4xx).
    class HttpError < Error
      attr_reader :url, :status, :body

      def initialize(url:, status:, body:)
        @url    = url
        @status = status
        @body   = body
        super("HTTP #{status} for #{url}: #{body.to_s[0, 200]}")
      end
    end

    # Upstream JSON came back with an unexpected structure — keys missing,
    # the wrong nesting, the wrong types. Never retry: the wire is broken
    # in a way a retry won't fix.
    class ShapeError < Error; end

    # A fetched value failed the positive-numeric guard. Treat as a data
    # bug upstream; failing fast is preferable to writing bad numbers.
    class ValidationError < Error; end

    # An on-disk file's contents don't satisfy the schema (wrong version,
    # missing required keys). Mirrors {Timeprice::UnsupportedSchemaVersion}
    # but lives in the pipeline namespace for catch-block clarity.
    class SchemaError < Error; end
  end
end
