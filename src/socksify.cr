# TODO: Write documentation for `Socksify`
require "socket"

require "diagnostic_logger"

require "./lib/exception"
require "./lib/extension"
require "./lib/tcp_socks_socket"
require "./lib/socks_proxy_delta"
require "./lib/http_client"

module Socksify
  VERSION = {{ system(%(shards version "#{__DIR__}")).chomp.stringify.downcase }}

  @@log = DiagnosticLogger.new "socksify-cr", Log::Severity::Debug


  # def self.resolve(host : String)
  #   s = TCPSOCKSSocket.new host, 80

  #   begin
  #     req = [] of String
  #     @@log.debug "Sending hostname to resolve: #{host}"
  #     req << "\005"
  #     if Socket.ip? host # to IPv4 address
  #       _ip = "\xF1\000\001"
  #       _ip += Array.pack_to_C host.split(".").map(&.to_i)
  #       req << _ip
  #     elsif host =~ /^[:0-9a-f]+$/  # to IPv6 address
  #       raise "TCP/IPv6 over SOCKS is not yet supported (inet_pton missing in Ruby & not supported by Tor"
  #       req << "\004"
  #     else                          # to hostname
  #       req << "\xF0\000\003" + Array.pack_to_C([host.size]) + host
  #     end
  #     req << Array.pack_to_n [0]  # Port
  #     @@log.debug "Sending #{req}"
  #     s.write req

  #     addr, _port = s.socks_receive_reply
  #     @@log.notice "Resolved #{host} as #{addr}:#{_port} over SOCKS"
  #     addr
  #   ensure
  #     s.close
  #   end
  # end

  def self.proxy(server : String, port : UInt)
    default_server = TCPSOCKSSocket.socks_server
    default_port = TCPSOCKSSocket.socks_port
    begin
      TCPSOCKSSocket.socks_server = server
      TCPSOCKSSocket.socks_port = port
      yield
    ensure
      TCPSOCKSSocket.socks_server = default_server
      TCPSOCKSSocket.socks_port = default_port
    end
  end
end
