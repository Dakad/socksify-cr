module HTTP
  class Client

    module SOCKSProxyDelta
      module ClassMethods
        property :socks_server
        property :socks_port
      end

      module InstanceMethods
        def address
          TCPSocket::SOCKSConnectionPeerAddress.new(self.class.socks_server, self.class.socks_port, @address)
        end
      end
    end

    extend SOCKSProxyDelta::ClassMethods
    include SOCKSProxyDelta::InstanceMethods

    def self.socksProxy(p_host, p_port)
      @@socks_server = p_host
      @@socks_port = p_port
    end
  end
end
