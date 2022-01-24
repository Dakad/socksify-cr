require "http"

require "./proxy"

class Socksify::HTTPClient < ::HTTP::Client

  @@log = DiagnosticLogger.new "http-client", ::Log::Severity::Debug

  getter proxy_url : String? = nil

  # Determine if HTTP request can skip proxy if failed to connect
  @skip_proxy : Bool = false

  def set_proxy(proxy : Proxy = nil)
    socket = @io
    return if socket && !socket.closed?

    begin
      Retriable.retry(on: {IO::Error, Socksify::SOCKSError}) do
        @proxy_url = proxy.proxy_url.not_nil!
        @io = proxy.open(@host, @port, @tls,  **proxy_connection_options)
      end
    rescue e : IO::Error
      @@log.fatal "Proxy could not opened : #{e}"
      abort 100 unless @skip_proxy
      # @io = nil
    end
    @@log.debug "my HTTPClient#set_proxy  proxy.open->io  #{@io.inspect}"
  end

  private def io
    io = @io
    # @@log.debug "my HTTPClient->io #{io.inspect}"
    return io if io

    set_proxy Proxy.new @proxy_url.not_nil! unless @proxy_url.nil?
    super #if @skip_proxy
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
