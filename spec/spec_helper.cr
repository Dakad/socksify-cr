require "spec"
require "../src/socksify"

module SpecHelper
  extend self

  def disable_socks
    TCPSocket.socks_server = nil
    TCPSocket.socks_port = nil
  end

  def enable_socks
    TCPSocket.socks_server = "127.0.0.1"
    TCPSocket.socks_port = 9001
  end

  def http_tor_proxy
    HTTP::Client.SOCKSProxy("127.0.0.1", 9050)
  end

  def internet_yandex_com_ip(http_klass = Net::HTTP)
    parse_internet_yandex_com_response get_http(http_klass, "https://213.180.204.62/internet", "yandex.com") # "http://yandex.com/internet"
  end

  def parse_check_response(body)
    if body.include? "This browser is configured to use Tor."
      is_tor = true
    elsif body.include? "You are not using Tor."
      is_tor = false
    else
      raise "Bogus response"
    end

    if body =~ /Your IP address appears to be:\s*<strong>(\d+\.\d+\.\d+\.\d+)<\/strong>/
        ip = $1
    else
      raise "Bogus response, no IP"
    end
    {is_tor, ip}
  end

  def parse_internet_yandex_com_response(body)
    if body =~ /<strong>IP-[^<]*<\/strong>: (\d+\.\d+\.\d+\.\d+)/
      ip = $1
    else
      raise "Bogus response, no IP" + "\n" + body.inspect
    end
    ip
  end

  def get_http(http_klass, url, host_header)
    uri = URI.parse url
    _get_http(http_klass, uri.scheme, uri.host, uri.port, uri.request_uri, host_header)
  end

  private  def _get_http(http_klass, scheme, host, port, path, host_header)
    body = nil
    http_klass.start(host, port,use_ssl: scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_MODE::NONE) do |http|
      req = HTTP::Client::Get.new path
      req["Host"] = host_header
      req["User-Agent"] = "crystal-socksify test"
      body = http.request(req).body
    end
    body
  end

end
