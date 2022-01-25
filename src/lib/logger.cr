require "diagnostic_logger"

module Socksify::Logger
  macro extended
    protected def self.logger
      @@logger ||= DiagnosticLogger.new({{@type.stringify}}, ::Log::Severity::Debug)
    end
  end
end
