require "../socksify"


module Socksify
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

end
