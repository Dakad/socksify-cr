require "http"

require "./logger"

class Socksify::HTTPClient < ::HTTP::Client
  extend Logger

  getter proxy_url : String? = nil

  # Determine if HTTP request can skip proxy
  # if failed to connect during the exec_request
  setter skip_proxy : Bool = false

  def set_proxy(proxy : Proxy = nil, is_fallback = true)
    socket = @io
    return if socket && !socket.closed?

    begin
      Retriable.retry(on: {IO::Error, Socksify::SOCKSError}) do
        @io = proxy.open(@host, @port, @tls,  **proxy_connection_options)
      end
      @proxy_url = proxy.proxy_url.not_nil!
    rescue e : IO::Error | Socksify::SOCKSError
      error_msg = "Failed to open connection on proxy '#{proxy.proxy_url}'"
      unless is_fallback
        raise Socksify::ProxyError::OpenConnectionError.new(error_msg, e)
      else
        raise Socksify::ProxyError::FallbackOpenConnectionError.new(error_msg, e)
      end
    end
    HTTPClient.logger.debug "my HTTPClient#set_proxy  proxy.open->io  #{@io.inspect}"
  end

  private def io : IO
    io = @io
    return io if io && !io.closed?

    begin
      set_proxy Proxy.new @proxy_url.not_nil!
    rescue e : ProxyError::OpenConnectionError
      if Proxy.has_fallback_proxy?
        set_proxy(Proxy.new(Proxy.config.fallback_proxy_url), is_fallback: true)
      else
        raise e
      end
    end
    return @io.not_nil!
  rescue e : ProxyError
    @skip_proxy ? return super : raise e
  end

  def self.new(uri : URI, tls = nil, ignore_config = false, use_fallback = false)
    inst = super(uri, tls)
    # Fallback proxy configured
    if use_fallback || (!ignore_config && Proxy.config.fallback_proxy_url?)
      inst.set_proxy(Proxy.new(Proxy.config.fallback_proxy_url), is_fallback: true)
    end

    inst
  end

  def self.new(uri : URI, tls = nil, ignore_config = false, use_fallback = false)
    yield new(uri, tls, ignore_config, use_fallback)
  end

  def proxy_connection_options
    {
      dns_timeout:     @dns_timeout,
      connect_timeout: @connect_timeout,
      read_timeout:    @read_timeout,
    }
  end
end
