require "http"

require "./logger"

class Socksify::HTTPClient < ::HTTP::Client
  extend Logger

  getter proxy_url : String? = nil

  # Determine if HTTP request can skip proxy if failed to connect
  getter skip_proxy : Bool = false

  def set_proxy(proxy : Proxy = nil, is_fallback = false)
    socket = @io
    return if socket && !socket.closed?

    begin
      Retriable.retry(on: {IO::Error, Socksify::SOCKSError}) do
        @proxy_url = proxy.proxy_url.not_nil!
        @io = proxy.open(@host, @port, @tls,  **proxy_connection_options)
      end
    rescue e : IO::Error
      HTTPClient.logger.fatal "Proxy could not opened : #{e}"
      #TODO: Instead of aborting, throw a specific Error
      abort 1000 if is_fallback
    end
    HTTPClient.logger.debug "my HTTPClient#set_proxy  proxy.open->io  #{@io.inspect}"
  end

  private def io
    io = @io
    # HTTPClient.logger.debug "my HTTPClient->io #{io.inspect}"
    return io if io

    begin
      set_proxy(Proxy.new @proxy_url.not_nil!) unless @proxy_url.nil?
    rescue e : IO::Error  # TODO: Replace by the specific ConnectionError
      if @skip_proxy && Proxy.has_fallback_proxy?
        set_proxy(Proxy.new(Proxy.config.fallback_proxy_url), is_fallback: true)
      end
    end
  rescue e : IO::Error  # TODO: Replace by the specific FallbackConnectionError
    @skip_proxy ? super : raise e
    #TODO Move the call super into ensure block so whatever we should try it
  end

  def self.new(uri : URI, tls = nil, ignore_config = false)
    inst = super(uri, tls)
    if !ignore_config && Proxy.has_fallback_proxy?
      inst.set_proxy Proxy.new(Proxy.config.fallback_proxy_url)
    end
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
