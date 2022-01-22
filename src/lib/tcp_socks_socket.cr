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


  def http_connect(host : String, port : Int32, auth : NamedTuple(username: String, password: String)? = nil)
    @@log.info "HTTP authentication ..." if auth
    credentials = Base64.strict_encode("#{auth[:username]}:#{auth[:password]}").gsub(/\s/, "") if auth
    str = ["CONNECT #{host}:#{port} HTTP/1.1\r\n"]
    str << "Host: #{host}:#{port}\r\n"
    str << "Proxy-Authorization: Basic #{credentials}\r\n" if credentials
    str << "User-Agent: curl/7.80.0\r\n"
    str << "Proxy-Connection: Keep-Alive\r\n"
    str << "\r\n"
    @@log.debug "CONNECT header #{str}"
    write str
    parse_response
  end

  private def parse_response
    res = {} of Symbol => Int32 | String | Hash(String, String)
    headers = {} of String => String
    version, code, reason = gets.as(String).chomp.split(/ /, 3)
    while (line = gets.as(String)) && (line.chomp != "")
      name, value = line.split(/:/, 2)
      headers[name.strip] = value.strip
    end
    res[:code] = code.to_i
    res[:reason] = reason
    res[:headers] = headers
    res
  rescue err
    raise IO::Error.new("parsing proxy initialization", cause: err)
  end

  # Authentication
  def socks_authenticate
    # From RFC1928: https://www.rfc-editor.org/rfc/rfc1928.html
    # 1st step is the authentication method handshake
    # +----+----------+---------+
    # |VER | NMETHODS | NAUTH   |
    # +----+----------+---------+
    # |X'5'|    X'1'  | 1 - 255 |
    # +----+----------+---------+
    # NAUTH can be:
    #   0 for no authentication
    #   2 for username/password. See RFC1929: https://www.rfc-editor.org/rfc/rfc1929.html
    if self.class.socks_username || self.class.socks_password
      @@log.info "Sending username/password authentication"
      send "\005\001\002"
    else
      @@log.info "Sending no authentication"
      send "\005\001\000"
    end

    # Response from server
    # +----+--------+
    # |VER | STATUS |
    # +----+--------+
    # | 1  |   1    |
    # +----+--------+
    # STATUS contains 2 possible values for requested nauth. method
    #   0 for success
    #   else it's considered failure :(
    @@log.debug "Waiting for authentication reply"
    auth_reply,_ = receive(2)
    if auth_reply.empty?
      raise Socksify::SOCKSError.new("Server doesn't reply authentication")
    end
    if auth_reply[0..0] != "\004" && auth_reply[0..0] != "\005"
      raise Socksify::SOCKSError.new("SOCKS version #{auth_reply[0..0]} not supported")
    end

    if self.class.socks_username.nil? && self.class.socks_password.nil?
      # No credentials, then the server reply must be for no auth
      if auth_reply[1..1] != "\000"
        raise Socksify::SOCKSError.new("SOCKS authentication method #{auth_reply[1..1]} neither requested nor supported")
      end
      return #
    end

    # Make sure the server accepts credentials auth request
    if auth_reply[1..1] != "\002"
      raise Socksify::SOCKSError.new("SOCKS authentication method #{auth_reply[1..1]} neither requested nor supported")
    end

    # From RFC1929: https://www.rfc-editor.org/rfc/rfc1929.html
    # Client authentication request looks like
    # +----+------+----------+------+----------+
    # |VER | ULEN |  UNAME   | PLEN |  PASSWD  |
    # +----+------+----------+------+----------+
    # |X'1'|  1   | 1 to 255 |  1   | 1 to 255 |
    # +----+------+----------+------+----------+
    # ULEN is the length of the user field that follows
    # PLEN is the length of the password field
    #
    auth = ["\001"]
    auth << self.class.socks_username.not_nil!.bytesize.to_s
    auth << self.class.socks_username.to_s
    auth << self.class.socks_password.not_nil!.bytesize.to_s
    auth << self.class.socks_password.to_s
    @@log.debug "Sending auth credentials " + auth.join
    send auth

    # Server response format:
    # +----+--------+
    # |VER | STATUS |
    # +----+--------+
    # |X'2'|   1    |
    # +----+--------+
    # STATUS contains 2 possible values for requested auth. method
    #   0 for success
    #   else it's considered failure :(
    auth_reply, _ = receive(2)
    if auth_reply[1..1] != "\000"
      raise Socksify::SOCKSError.new("SOCKS authentication failed")
    end
  end



  # Connect
  def socks_connect(host : String, port : Int)
    # FROM RFC1928 : https://www.rfc-editor.org/rfc/rfc1928.html#section-4
    # Client connection request
    # +-----+-----+-------+------+----------+----------+
    # | VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
    # +-----+-----+-------+------+----------+----------+
    # |X'01'|  1  | X'00' |  1   | Variable |    2     |
    # +---- +-----+-------+------+----------+----------+
    # CMD can have 3 possible values
    #   X'01': Connect -  TCP/IP stream connection
    #   X'02': Bind -  TCP/IP port binding
    #   X'03': UPD ASSOC - Assoc a UDP port
    # RSV: RESERVED, always set to X'00'
    @@log.info "SOCKS connect ..."
    @@log.debug "Sending client host address"
    req = [] of String
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

    # ATYP: Address type
    #   X'01': IPv4 address
    #   X'03': Domain address
    #   X'04': IPv6 address
    # DST.ADDR: Host destination address.
    # The field size depends on the ATYP field value
    #   * 4 bytes for the IPv4 address
    #   * 1 byte of name length followed by 1–255 bytes for the domain name
    #   * 16 bytes for IPv6 address
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

    # DST.PORT: Host destination port in network byte order (Big endian)
    req << Array.pack_to_n [port] if @@socks_version == "5"
    @@log.debug "Send connect req: #{req.join}"
    send req

    s_addr, s_port = socks_receive_reply
    @@log.debug "Connected to #{s_addr}:#{s_port} over SOCKS"
  end

  # returns [bind_addr: String, bind_port: Int]
  private def socks_receive_reply : Tuple(String?, Int32)
    bind_addr = ""
    bind_port = 0

    # From RFC1928 : https://www.rfc-editor.org/rfc/rfc1928.html#section-6
    # Response from server after establing a connection
    # +----+-----+-------+------+----------+----------+
    # | VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
    # +-----+-----+-------+------+----------+----------+
    # | 1   |  1  | X'00' |  1   | Variable |    2     |
    # +-----+-----+-------+------+----------+----------+
    #
    # VER: SOCKS version (X'05' or X'04')
    # RSV: RESERVED, always X'00'

    @@log.debug "Waiting for SOCKS reply"
    if @@socks_version == "5"
      connect_reply,_ = receive(4)
      @@log.debug "Reply #{connect_reply.chars}"
      raise Socksify::SOCKSError.new("Server doesn't reply") if connect_reply.empty?
      if connect_reply[0..0] != "\005"
        raise Socksify::SOCKSError.new("SOCKS version #{connect_reply[0..0]} is not 5")
      end

      # REP: Reply field
      #   X'00' succeeded
      #   X'01' general SOCKS server failure
      #   X'02' connection not allowed by ruleset
      #   X'03' Network unreachable
      #   X'04' Host unreachable
      #   X'05' Connection refused
      #   X'06' TTL expired
      #   X'07' Command not supported
      #   X'08' Address type not supported
      #   X'09' to X'FF' unassigned
      if connect_reply[1..1] != "\000"
        code = connect_reply.bytes.first
        pp Socksify::SOCKSError.for_response_code(code)
      end

      # ATYP: Address type
      #   X'01': IPv4 address, 4 bytes
      #   X'03': Domain name,
      #   X'04': IPv6 address, 16 bytes
      bind_addr_len = 0
      @@log.debug "Waiting for bind_addr"
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

      # BIND.ADDR: Server bound addess.
      # Will probably be 0.0.0.0 (dummy data :/). The local machine has no need to know  this info.
      # Not an issue since the server will do a DNS resolution before fetching the page
      bind_addr_s, _ = receive(bind_addr_len)
      @@log.debug "Bind_addr received of size #{bind_addr_len}, #{bind_addr_s.chars}"
      bind_addr = case connect_reply[3..3]
                  when "\001"
                    bind_addr_s.bytes.to_a.join('.')
                  when "\003"
                    bind_addr_s.to_s
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
                  else
                    nil
                  end

      # BIND.PORT: Server bound port
      # will also probably be 00 (dummy value :/)
      bind_port, _ = receive(bind_addr_len + 2)
      bind_port = bind_port.bytes.reverse.map_with_index { |nb, i| nb * (10**i) }.sum.to_i32
      p! bind_port
    else
      connect_reply,_ = receive(8)
      unless connect_reply[0] == "\000" && connect_reply[1] == "\x5A"
        # @@log.debug connect_reply#.unpack "H"
        raise Socksify::SOCKSError.new("Failed while connecting througth socks")
      end
    end
    p! bind_addr, bind_port
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
    p str
    write str.join.to_slice
  end
end

