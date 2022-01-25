require "openssl"

require "./exception"
require "./logger"
require "./tcp_socks_socket"

class Socksify::Proxy
  extend Logger

  alias Credential = NamedTuple(username: String, password: String)

  class_property username : String? = ENV["PROXY_USERNAME"]?
  class_property password : String? = ENV["PROXY_PASSWORD"]?
  class_property proxy_uri : String? = ENV["PROXY_URI"]?
  class_property verify_tls : Bool = ENV["PROXY_VERIFY_TLS"]? != "false"
  class_property disable_crl_checks : Bool = ENV["PROXY_DISABLE_CRL_CHECKS"]? == "true"
  class_getter config : Config { Config.new }

  # The hostname or IP address of the HTTP proxy.
  getter proxy_host : String

  # The port number of the proxy.
  getter proxy_port : Int32

  # The fulll URL of the PROXY starting by the scheme (socks or http)
  getter proxy_url : String?

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
    scheme = uri.scheme || "socks5"
    port = uri.port || URI.default_port(uri.scheme.not_nil!).not_nil!
    creds = {username: user, password: pass} if user && pass
    {host, port, creds, scheme}
  rescue
    raise "Missing/malformed $http_proxy or $https_proxy in environment"
  end

  def initialize(@proxy_url : String)
    uri = URI.parse @proxy_url.not_nil!
    if uri.host.nil?
      host = @proxy_url.not_nil!.gsub(/^sock[s]?\:\/\//, "")
      if host.includes? ":"
        uri.host, _port = host.split ":"
        uri.port = _port.to_i
      else
        uri.host = host
        uri.port = 0
      end
    end

    unless uri.user.nil? || uri.password.nil?
      creds = {
        username: uri.user.not_nil!,
        password: uri.password.not_nil!
      }
    end
    initialize(uri.host.not_nil!, uri.port.not_nil!, creds, uri.scheme || "socks5")
  end

  # Create a new socket factory that tunnels via the given host and
  # port. The +options+ parameter is a hash of additional settings that
  # can be used to tweak this proxy connection. Specifically, the following
  # options are supported:
  #
  # * :username => the user name to use when authenticating to the proxy
  # * :password => the password to use when authenticating
  private def initialize(@proxy_host : String, @proxy_port : Int32, @proxy_auth : Credential? = nil, @proxy_scheme :  String = "")
    if !@proxy_auth && self.class.username && self.class.password
      @proxy_auth = {username: self.class.username.as(String), password: self.class.password.as(String)}
    end
  end

  # Return a new socket connected to the given host and port via the
  # proxy that was requested when the socket factory was instantiated.
  def open(host, port, tls = nil, **connection_options)
    dns_timeout = connection_options[:dns_timeout] || Proxy.config.timeout_sec
    connect_timeout = connection_options[:connect_timeout] || Proxy.config.connect_timeout_sec
    read_timeout = connection_options[:read_timeout] || Proxy.config.timeout_sec

    Proxy.logger.debug "Creating TCPSOCKSSocket"
    socket = TCPSOCKSSocket.new @proxy_host, @proxy_port, dns_timeout, connect_timeout
    socket.read_timeout = read_timeout if read_timeout
    socket.sync = true

    case @proxy_scheme
    when "http", "https"
      Proxy.logger.info "Connecting to HTTP proxy #{@proxy_host}:#{@proxy_port}"
      resp = socket.http_connect host, port, @proxy_auth
      Proxy.logger.info "Proxy response #{resp[:code]} #{resp[:reason]}"
      unless resp[:code]? == 200
        socket.close
        raise IO::Error.new(resp.inspect)
      end
    when "socks", "socks4", "socks5"
      begin
        Proxy.logger.info "Connecting to SOCKS proxy #{@proxy_host}:#{@proxy_port}"
        socket.socks_authenticate
        socket.socks_connect host, port
      rescue e : Socksify::SOCKSError
        socket.close
        raise IO::Error.new(e.message)
      end
    end

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
  end

  def self.configure
    yield config
  end

  class Config
    property connect_timeout_sec : Int32 = 60
    property timeout_sec : Int32 = 60

    getter max_retries : Int32 = 1
    def max_retries=(@max_retries)
      Retriable.configure { |settings| settings.max_attempts = @max_retries }
    end

    getter proxy
    def proxy=(proxies)
      @proxy = proxies.split /,|;/
    end

  end   # Proxy::Config

end     # Socksify::Proxy
