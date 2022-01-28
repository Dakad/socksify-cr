require "../src/socksify"

Socksify::Proxy.configure do |config|
  config.timeout_sec = 50
  config.max_retries = 3
  # config.fallback_proxy_uri = "socks5://127.0.0.1:9150"
end

host = "https://ipconfig.me"
client = Socksify::HTTPClient.new(URI.parse(host), ignore_config: true)
proxy = Socksify::Proxy.new("socks://192.111.130.5:17002")
# proxy = Socksify::Proxy.new("socks5://198.199.109.36:62287")
# proxy = Socksify::Proxy.new("socks4://181.236.221.138:4145")
# proxy = Socksify::Proxy.new("http://140.227.238.217:3128")
# proxy = Socksify::Proxy.new("http://54.94.249.0:9080")
# proxy = Socksify::Proxy.new("socks://127.0.0.1:9150")

client.set_proxy(proxy)
response = client.exec("GET", "/ip", headers: HTTP::Headers{"User-Agent" => "curl/7.80.0"})
pp response.body
client.close
