module Socksify

  class SOCKSError < RuntimeError
    def initialize(msg)
      # @@log.debug("#{self.class}: #{msg}")
      super
      p("#{self.class}: #{msg}")
    end
    class ServerFailure < SOCKSError
      def initialize
        super("general SOCKS server failure")
      end
    end
    class NotAllowed < SOCKSError
      def initialize
        super("connection not allowed by ruleset")
      end
    end
    class NetworkUnreachable < SOCKSError
      def initialize
        super("Network unreachable")
      end
    end
    class HostUnreachable < SOCKSError
      def initialize
        super("Host unreachable")
      end
    end
    class ConnectionRefused < SOCKSError
      def initialize
        super("Connection refused")
      end
    end
    class TTLExpired < SOCKSError
      def initialize
        super("TTL expired")
      end
    end
    class CommandNotSupported < SOCKSError
      def initialize
        super("Command not supported")
      end
    end
    class AddressTypeNotSupported < SOCKSError
      def initialize
        super("Address type not supported")
      end
    end

    def self.for_response_code(code) : SOCKSError
      case code
      when 1
        ServerFailure.new
      when 2
        NotAllowed.new
      when 3
        NetworkUnreachable.new
      when 4
        HostUnreachable.new
      when 5
        ConnectionRefused.new
      when 6
        TTLExpired.new
      when 7
        CommandNotSupported.new
      when 8
        AddressTypeNotSupported.new
      else
        self.new("Unknown response code #{code}")
      end
    end
  end
end

