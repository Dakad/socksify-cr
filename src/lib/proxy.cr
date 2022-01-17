require "openssl"

require "./exception"
require "./tcp_socks_socket"

module Socksify

  class Proxy
    @@log = DiagnosticLogger.new "proxy-cr", Log::Severity::Debug

    class_property username : String? = ENV["PROXY_USERNAME"]?
    class_property password : String? = ENV["PROXY_PASSWORD"]?
    class_property proxy_uri : String? = ENV["PROXY_URI"]?
    class_property verify_tls : Bool = ENV["PROXY_VERIFY_TLS"]? != "false"
    class_property disable_crl_checks : Bool = ENV["PROXY_DISABLE_CRL_CHECKS"]? == "true"

    # The hostname or IP address of the HTTP proxy.
    getter proxy_host : String

    # The port number of the proxy.
    getter proxy_port : Int32

    # The map of additional options that were given to the object at
    # initialization.
    getter tls : OpenSSL::SSL::Context::Client?

    # Simple check for relevant environment
    def self.behind_proxy?
      !!proxy_uri
    end

    # Grab the host, port from URI
    def self.parse_proxy_url
      proxy_url = proxy_uri.not_nil!

      uri = URI.parse(proxy_url)
      user = uri.user || username
      pass = uri.password || password
      host = uri.host.not_nil!
      port = uri.port || URI.default_port(uri.scheme.not_nil!).not_nil!
      creds = {username: user, password: pass} if user && pass
      {host, port, creds}
    rescue
      raise "Missing/malformed $http_proxy or $https_proxy in environment"
    end


    # Create a new socket factory that tunnels via the given host and
    # port. The +options+ parameter is a hash of additional settings that
    # can be used to tweak this proxy connection. Specifically, the following
    # options are supported:
    #
    # * :username => the user name to use when authenticating to the proxy
    # * :password => the password to use when authenticating
    def initialize(host : String, port : Int32, auth : NamedTuple(username: String, password: String)? = nil)
      @proxy_host = host.gsub(/^http[s]?\:\/\//, "")
      if host.includes? ":"
        @proxy_host, px_port = @proxy_host.split ":"
        @proxy_port = px_port.to_i
      else
        @proxy_port = port
      end
      if !auth && self.class.username && self.class.password
        auth = {username: self.class.username.as(String), password: self.class.password.as(String)}
        # @credentials = Base64.strict_encode("#{auth[:username]}:#{auth[:password]}").gsub(/\s/, "") if auth
      end
    end

    # Return a new socket connected to the given host and port via the
    # proxy that was requested when the socket factory was instantiated.
    def open(host, port, tls = nil, **connection_options)
      dns_timeout = connection_options.fetch(:dns_timeout, nil)
      connect_timeout = connection_options.fetch(:connect_timeout, nil)
      read_timeout = connection_options.fetch(:read_timeout, nil)

      socket = TCPSOCKSSocket.new @proxy_host, @proxy_port#, dns_timeout, connect_timeout
      socket.read_timeout = read_timeout if read_timeout
      socket.sync = true

      # resp = parse_response(socket)

      # if resp[:code]? == 200
        if tls
          if tls.is_a?(Bool) # true, but we want to get rid of the union
            context = OpenSSL::SSL::Context::Client.new
          else
            context = tls
          end

          if !Proxy.verify_tls
            context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
          elsif Proxy.disable_crl_checks
            context.add_x509_verify_flags OpenSSL::SSL::X509VerifyFlags::IGNORE_CRITICAL
          end

          socket = OpenSSL::SSL::Socket::Client.new(socket, context: context, sync_close: true, hostname: host)
        end

        socket
      # else
      #   socket.close
      #   raise IO::Error.new(resp.inspect)
      # end
    end
  end
end
