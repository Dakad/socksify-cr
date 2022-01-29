require "http"

require "./logger"

class Socksify::HTTPClient < ::HTTP::Client
  extend Logger

  getter proxy_url : String? = nil

  # Determine if HTTP request can skip proxy
  # if failed to connect during the exec_request
  setter skip_proxy : Bool = false

  def set_proxy(proxy : Proxy = nil)
    socket = @io
    return if socket && !socket.closed?

    begin
      Retriable.retry(on: {IO::Error, Socksify::SOCKSError}) do
        @io = proxy.open(@host, @port, @tls,  **proxy_connection_options)
      end
      @proxy_url = proxy.proxy_url.not_nil!
    rescue e : IO::Error | Socksify::SOCKSError
      error_msg = "Failed to open connection on proxy '#{proxy.proxy_url}'"
      raise Socksify::ProxyError::OpenConnectionError.new(error_msg, e)
    end
    HTTPClient.logger.debug "my HTTPClient#set_proxy  proxy.open->io  #{@io.inspect}"
  end

  private def io : IO
    io = @io
    return io if io && !io.closed?

    set_proxy Proxy.new @proxy_url.not_nil!
    return @io.not_nil!
  rescue e : ProxyError::OpenConnectionError
    @skip_proxy ? return super  : raise e
  end

  def self.new(uri : URI, tls = nil, ignore_config = false)
    inst = super(uri, tls)
    # if !ignore_config && Proxy.behind_proxy?
    #   inst.set_proxy Proxy.new(*Socksify::Proxy.parse_proxy_url)
    # end
    inst
  end

  def self.new(uri : URI, tls = nil, ignore_config = false)
    yield new(uri, tls, ignore_config)
  end

  def proxy_connection_options
    {
      dns_timeout:     @dns_timeout,
      connect_timeout: @connect_timeout,
      read_timeout:    @read_timeout,
    }
  end
end
