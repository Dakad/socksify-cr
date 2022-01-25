# TODO: Write documentation for `Socksify`

require "retriable"
require "retriable/core_ext/kernel"

require "./lib/*"

module Socksify
  extend Logger

  VERSION = {{ system(%(shards version "#{__DIR__}")).chomp.stringify.downcase }}

  Retriable.configure do |settings|
    # Number of attempts to make at running your code block (includes initial attempt)
    # settings.max_attempts = Proxy.config.max_retries

    # The initial interval between tries.
    settings.base_interval = 30.seconds

    # The maximum interval that any individual retry can reach.
    settings.max_interval = 2.minute

    # The maximum amount of total time that block code is allowed to keep being retried.
    settings.max_elapsed_time = 4.minutes

    # Use Exponential backoff strategy
    settings.backoff = true

    # Proc to call after each try is rescued
    settings.on_retry = ->(ex : Exception, attempt : Int32, elapsed_time : Time::Span, next_interval : Time::Span) do
      logger.warn "#{ex.class}: '#{ex.message}' - #{attempt} attempt in #{elapsed_time} sec and #{next_interval} sec until the next try."
    end
  end


  # def self.resolve(host : String)
  #   # TODO: Create a TCPSOCKSSocket using a default socks server
  #   s = TCPSOCKSSocket.new
  #   s.socks_connect

  #   begin
  #     req = [] of String
  #     logger.debug "Sending hostname to resolve: #{host}"
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
  #     logger.debug "Sending #{req}"
  #     s.write req

  #     addr, _port = s.socks_receive_reply
  #     logger.notice "Resolved #{host} as #{addr}:#{_port} over SOCKS"
  #     addr
  #   ensure
  #     s.close
  #   end
  # end

end
