require "socket"

require "./exception"

class TCPSOCKSSocket < TCPSocket

  @@log = DiagnosticLogger.new "tcp-socks-socket", Log::Severity::Debug

  class_getter socks_version : String = "5"
  class_property socks_server : String?
  class_property socks_port : Int32?
  class_property socks_username : String?
  class_property socks_password : String?
  class_property socks_ignores : Array(String) =  %w(localhost)

  def self.socks_version : String
    @@socks_version =~ /^4/ ? "\004" : "\005"
  end


  struct SOCKSConnectionPeerAddress
    getter :socks_server, :socks_port, :peer_host

    # delegate to_s, @peer_host

    def initialize(@socks_server, @socks_port, @socks_username, @socks_password, @peer_host)
    end

    def inspect
      "#{to_s} (via #{@socks_server}:#{@socks_port})"
    end
  end


  # See http://tools.ietf.org/html/rfc1928
  # def initialize(host, port)

  #   if host.is_a? SOCKSConnectionPeerAddress
  #     socks_peer = host
  #     socks_server = socks_peer.socks_server
  #     socks_port = socks_peer.socks_port
  #     socks_ignores = [] of String
  #     host = socks_peer.peer_host
  #   else
  #     socks_server = self.class.socks_server
  #     socks_port = self.class.socks_port
  #     socks_ignores = self.class.socks_ignores
  #   end

  #   p! socks_server,socks_port#,local_host,local_port,socks_ignores
  #   if socks_server && socks_port && !socks_ignores.includes?(host)
  #     @socket = TCPSocket.new socks_server, socks_port
  #     socks_authenticate unless @@socks_version =~ /^4/
  #     socks_connect(host, port) if host
  #   else
  #     @@log.debug "Connecting directly to #{host}:#{port}"
  #     @socket = TCPSocket.new host, port
  #     @@log.debug "Connected to #{host}:#{port}"
  #   end
  #   @socket
  # end

  def http_connect(host : String, port : Int32, auth : NamedTuple(username: String, password: String)? = nil)
    @@log.info "HTTP authentication ..."
    credentials = Base64.strict_encode("#{auth[:username]}:#{auth[:password]}").gsub(/\s/, "") if auth
    str = ["CONNECT #{host}:#{port} HTTP/1.0\r\n"]
    str << "Host: #{host}:#{port}\r\n"
    str << "Proxy-Authorization: Basic #{credentials}\r\n" if credentials
    str << "\r\n"
    @@log.debug "CONNECT header #{str}"
    write str
    parse_response
  end

  private def parse_response
    res = {} of Symbol => Int32 | String | Hash(String, String)

    begin
      version, code, reason = gets.as(String).chomp.split(/ /, 3)
      headers = {} of String => String
      while (line = gets.as(String)) && (line.chomp != "")
        name, value = line.split(/:/, 2)
        headers[name.strip] = value.strip
      end
      res[:code] = code.to_i
      res[:reason] = reason
      res[:headers] = headers
    rescue error
      raise IO::Error.new("parsing proxy initialization", cause: error)
    end
    res
  end

  # Authentication
  def socks_authenticate
    @@log.info "SOCKS authentication ..."
    if self.class.socks_username || self.class.socks_password
      @@log.info "Sending username/password authentication"
      send "\005\001\002"
    else
      @@log.info "Sending no authentication"
      send "\005\001\000"
    end

    @@log.debug "Waiting for authentication reply"
    auth_reply,_ = receive(2)
    if auth_reply.empty?
      raise Socksify::SOCKSError.new("Server doesn't reply authentication")
    end
    p! auth_reply
    if auth_reply[0..0] != "\004" && auth_reply[0..0] != "\005"
      raise Socksify::SOCKSError.new("SOCKS version #{auth_reply[0..0]} not supported")
    end
    if !self.class.socks_username.nil? || !self.class.socks_password.nil?
      if auth_reply[1..1] != "\002"
        raise Socksify::SOCKSError.new("SOCKS authentication method #{auth_reply[1..1]} neither requested nor supported")
      end
      auth = ["\001"]
      auth << self.class.socks_username.not_nil!.bytesize.to_s
      auth << self.class.socks_username.to_s
      auth << self.class.socks_password.not_nil!.bytesize.to_s
      auth << self.class.socks_password.to_s
      @@log.debug "Sending auth credentials " + auth.join
      send auth
      auth_reply, _ = receive(2)
      if auth_reply[1..1] != "\000"
        raise Socksify::SOCKSError.new("SOCKS authentication failed")
      end
    else
      if auth_reply[1..1] != "\000"
        raise Socksify::SOCKSError.new("SOCKS authentication method #{auth_reply[1..1]} neither requested nor supported")
      end
    end
  end

  # Connect
  def socks_connect(host : String, port : Int)
    @@log.info "SOCKS connect ..."
    # port = Socket.getservbyname(port) if port.is_a?(String)
    req = [] of String
    @@log.debug "Sending destination address"
    req << TCPSOCKSSocket.socks_version
    @@log.debug TCPSOCKSSocket.socks_version#.unpack "H*"
    req << "\001"
    req << "\000" if @@socks_version == "5"
    req << Array.pack_to_n [port] if @@socks_version =~ /^4/

    if @@socks_version == "4"
      # DNS resolve the host if it's a domain "example.com"
      addrinfos = Socket::Addrinfo.resolve(host, "http", type: Socket::Type::STREAM, protocol: Socket::Protocol::TCP)
      p! addrinfos.to_s
      host = addrinfos.first.ip_address.to_s
    end
    if Socket.ip? host # to IPv4 address
      req << "\001" if @@socks_version == "5"
      _ip = Array.pack_to_C host.split(".").map(&.to_i)
      req << _ip
    elsif host =~ /^[:0-9a-f]+$/  # to IPv6 address
      raise "TCP/IPv6 over SOCKS is not yet supported (inet_pton missing in Ruby & not supported by Tor"
      req << "\004"
    else        # to hostname
      if @@socks_version == "5"
        req << "\003" + Array.pack_to_C([host.size]) + host
      else
        req << "\000\000\000\001"
        req << "\007\000"
        req << host
        req << "\000"
      end
    end
    req << Array.pack_to_n [port] if @@socks_version == "5"
    # @@log.debug "Send connect req: " + req.join
    send req

    s_addr, s_port = socks_receive_reply
    @@log.debug "Connected to #{s_addr}:#{s_port} over SOCKS"
  end

  # returns [bind_addr: String, bind_port: Fixnum]
  private def socks_receive_reply : Tuple(String?, Int32|String)
    bind_addr = ""
    bind_port = 0

    # debugger
    @@log.debug "Waiting for SOCKS reply"
    if @@socks_version == "5"
      connect_reply,_ = receive(4)
      @@log.debug "Reply #{connect_reply.chars}"
      raise Socksify::SOCKSError.new("Server doesn't reply") if connect_reply.empty?
      if connect_reply[0..0] != "\005"
        @@log.debug connect_reply
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
        msg,_ = receive(1)
        bind_addr_len = msg.bytes.first
      when "\004"
        bind_addr_len = 16
      else
        raise Socksify::SOCKSError.for_response_code(connect_reply.bytes.to_a[3])
      end
      bind_addr_s,_ = receive(bind_addr_len)
      @@log.debug "Bind_addr received of size #{bind_addr_len}, #{bind_addr_s.chars}"
      bind_addr = case connect_reply[3..3]
                  when "\001"
                    bind_addr_s.bytes.to_a.join('.')
                  when "\003"
                    bind_addr_s
                  when "\004"  # Untested!
                    # i = 0
                    # ip6 = ""
                    # bind_addr_s.each_byte do |b|
                    #   if i > 0 && i % 2 == 0
                    #     ip6 += ":"
                    #   end
                    #   i += 1

                    #   ip6 += b.to_s(16).rjust(2, '0')
                    # end
                  end
      bind_port, _ = receive(bind_addr_len + 2)
    else
      connect_reply,_ = receive(8)
      unless connect_reply[0] == "\000" && connect_reply[1] == "\x5A"
        @@log.debug connect_reply#.unpack "H"
        raise Socksify::SOCKSError.new("Failed while connecting througth socks")
      end
    end
    {bind_addr, bind_port}
  end

  # def receive(message_size = 512) : String
  #   message,addr = super.receive message_size
  #   message
  # end

  def receive(message : Bytes) : String
    bytes_read,addr = receive(message)
    bytes_read
  end

  def send(message : Array(String))
    send message.join
  end

  # def send(message : String)
  #   super.send(message)
  # end

  def write(str : Array(String))
    # p str
    write str.join.to_slice
  end
end

