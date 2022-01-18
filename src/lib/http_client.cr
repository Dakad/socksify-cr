require "http"

require "./tcp_socks_socket.cr"
require "./proxy"

module Socksify
  class HTTPClient < ::HTTP::Client

    def set_proxy(proxy : Proxy = nil)
      socket = @io
      return if socket && !socket.closed?

      begin
        @io = proxy.open(@host, @port)
      rescue IO::Error
        @io = nil
      end
    end

    def self.new(uri : URI, tls = nil, ignore_env = false)
      inst = super(uri, tls)
      # if !ignore_env && Proxy.behind_proxy?
      #   inst.set_proxy Proxy.new(*Socksify::Proxy.parse_proxy_url)
      # end
      inst
    end

    def self.new(uri : URI, tls = nil, ignore_env = false)
      yield new(uri, tls, ignore_env)
    end


    def proxy_connection_options
      {
        dns_timeout:     @dns_timeout,
        connect_timeout: @connect_timeout,
        read_timeout:    @read_timeout,
      }
    end
  end
end
