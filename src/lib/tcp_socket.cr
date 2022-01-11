class TCPSocket
  # @@socks_version = "5"

  @@log = DiagnosticLogger.new "socksify-cr", Log::Severity::Debug

  class_getter socks_version : String = "5"
  class_property socks_server : String?
  class_property socks_port : Int32?
  class_property socks_username : String?
  class_property socks_password : String?
  class_property socks_ignores : Array(String) =  %w(localhost)

  def self.socks_version : String
    (@@socks_version == "4a" || @@socks_version == "4") ? "\004" : "\005"
  end


  struct SOCKSConnectionPeerAddress
    getter :socks_server, :socks_port, :peer_host

    # delegate to_s, @peer_host

    def initialize(@socks_server, @socks_port, @peer_host)
    end

    def inspect
      "#{to_s} (via #{@socks_server}:#{@socks_port})"
    end
  end

  # See http://tools.ietf.org/html/rfc1928
  def initialize(host=nil, port=0, local_host=nil, local_port=nil)
    if host.is_a? SOCKSConnectionPeerAddress
      socks_peer = host
      socks_server = socks_peer.socks_server
      socks_port = socks_peer.socks_port
      socks_ignores = [] of String
      host = socks_peer.peer_host
    else
      socks_server = self.class.socks_server
      socks_port = self.class.socks_port
      socks_ignores = self.class.socks_ignores
    end

    p! socks_server,socks_port,local_host,local_port,socks_ignores
    if socks_server && socks_port && !socks_ignores.include?(host)
      @@log.debug "Connecting to SOCKS server #{socks_server}:#{socks_port}"
      connect socks_server, socks_port
      socks_authenticate unless @@socks_version =~ /^4/
      socks_connect(host, port) if host
    else
      @@log.debug "Connecting directly to #{host}:#{port}"
      initialize host, port, local_host, local_port
      @@log.debug "Connected to #{host}:#{port}"
    end
  end

  # Authentication
  def socks_authenticate
    if self.class.socks_username || self.class.socks_password
      @@log.debug "Sending username/password authentication"
      send "\005\001\002"
    else
      @@log.debug "Sending no authentication"
      send "\005\001\000"
    end

    @@log.debug "Waiting for authentication reply"
    auth_reply,_ = receive(2)
    if auth_reply.empty?
      raise SOCKSError.new("Server doesn't reply authentication")
    end
    if auth_reply[0..0] != "\004" && auth_reply[0..0] != "\005"
      raise SOCKSError.new("SOCKS version #{auth_reply[0..0]} not supported")
    end
    if self.class.socks_username || self.class.socks_password
      if auth_reply[1..1] != "\002"
        raise SOCKSError.new("SOCKS authentication method #{auth_reply[1..1]} neither requested nor supported")
      end
      auth = "\001"
      auth += self.class.socks_username.bytesize
      auth += self.class.socks_username.to_s
      auth += self.class.socks_password.bytesize
      auth += self.class.socks_password.to_s
      @@log.debug "Sending auth credentials : " + auth
      send auth
      auth_reply = receive(2)
      if auth_reply[1..1] != "\000"
        raise SOCKSError.new("SOCKS authentication failed")
      end
    else
      if auth_reply[1..1] != "\000"
        raise SOCKSError.new("SOCKS authentication method #{auth_reply[1..1]} neither requested nor supported")
      end
    end
  end

  # Connect
  def socks_connect(host, port)
    # port = Socket.getservbyname(port) if port.is_a?(String)
    req = String.new
    @@log.debug "Sending destination address"
    req << TCPSocket.socks_version
    @@log.debug TCPSocket.socks_version.unpack "H*"
    req << "\001"
    req << "\000" if @@socks_version == "5"
    req << [port].pack('n') if @@socks_version =~ /^4/

    if @@socks_version == "4"
      # DNS resolve the host if it's a domain "example.com"
      addrinfos = Socket::Addrinfo.resolve(host)
      host = addrinfos.first.ip_address.to_s
    end
    @@log.debug host
    if Socket.ip? host # to IPv4 address
      req << "\001" if @@socks_version == "5"
      _ip = host.split(".").map(&.to_i).pack("CCCC")
      req << _ip
    elsif host =~ /^[:0-9a-f]+$/  # to IPv6 address
      raise "TCP/IPv6 over SOCKS is not yet supported (inet_pton missing in Ruby & not supported by Tor"
      req << "\004"
    else                          # to hostname
      if @@socks_version == "5"
        req << "\003" + [host.size].pack('C') + host
      else
        req << "\000\000\000\001"
        req << "\007\000"
        req << host
        req << "\000"
      end
    end
    req << [port].pack('n') if @@socks_version == "5"
    @@log.debug "Send connect req: " + req
    send req

    socks_receive_reply
    @@log.debug "Connected to #{host}:#{port} over SOCKS"
  end

  # returns [bind_addr: String, bind_port: Fixnum]
  def socks_receive_reply()
    bind_addr = ""
    bind_port = 0

    @@log.debug "Waiting for SOCKS reply"
    if @@socks_version == "5"
      connect_reply = receive(4).first
      if connect_reply.empty?
        raise Socksify::SOCKSError.new("Server doesn't reply")
      end
      # @@log.debug connect_reply.unpack "H*"
      if connect_reply[0..0] != "\005"
        raise Socksify::SOCKSError.new("SOCKS version #{connect_reply[0..0]} is not 5")
      end
      if connect_reply[1..1] != "\000"
        code = connect_reply.bytes.first
        pp Socksify::SOCKSError.for_response_code(code)
      end
      @@log.debug "Waiting for bind_addr"
      bind_addr_len = 0
      case connect_reply[3..3]
      when "\001"
        bind_addr_len = 4
      when "\003"
        msg = receive(1).first
        bind_addr_len = msg.bytes.first
      when "\004"
        bind_addr_len = 16
      else
        raise Socksify::SOCKSError.for_response_code(connect_reply.bytes.to_a[3])
      end
      # bind_addr_s = receive(bind_addr_len).first
      # bind_addr = case connect_reply[3..3]
      #             when "\001"
      #               bind_addr_s.bytes.to_a.join('.')
      #             when "\003"
      #               bind_addr_s
      #             when "\004"  # Untested!
      #               i = 0
      #               ip6 = ""
      #               bind_addr_s.each_byte do |b|
      #                 if i > 0 && i % 2 == 0
      #                   ip6 += ":"
      #                 end
      #                 i += 1

      #                 ip6 += b.to_s(16).rjust(2, '0')
      #               end
      #             end
      # bind_port = receive(bind_addr_len + 2).first
    else
      connect_reply = receive(8)
      unless connect_reply[0] == "\000" && connect_reply[1] == "\x5A"
        @@log.debug connect_reply.unpack "H"
        raise Socksify::SOCKSError.new("Failed while connecting througth socks")
      end
    end
    [bind_addr, bind_port]
  end

  def receive(message_size = 512)
    message,_ = receive message_size
    message
  end

  def receive(message : Bytes) : String
    bytes_read,_ = receive(message)
    bytes_read
  end

  def write(str : Array(String))
    p str
    write str.join.to_slice
  end
end

