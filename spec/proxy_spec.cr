require "./spec_helper.cr"
# require "../src/lib/proxy"
# require "../src/lib/http_client"

describe Socksify::HTTPClient do

  it "connect to a website and get a response" do
    host = URI.parse("https://ifconfig.me")
    response = Socksify::HTTPClient.new(host) do |client|
      client.exec("GET", "/all")
    end
    response.success?.should eq(true)
  end

  it "connect to a website and get a response using explicit proxy", do
    host = URI.parse("https://ifconfig.me")
    client = Socksify::HTTPClient.new(host, ignore_env: true)
    # proxy = Socksify::Proxy.new("socks://104.131.8.62:10808")
    # proxy = Socksify::Proxy.new("http://140.227.238.217:3128")
    # proxy = Socksify::Proxy.new("socks5://144.76.224.49:63640")
    # proxy = Socksify::Proxy.new("socks://202.107.74.24:7302")
    proxy = Socksify::Proxy.new("http://45.72.3.134:8118")
    client.set_proxy(proxy)
    response = client.exec("GET", "/ip")
    response.success?.should eq(true)
    response.body.to_s.should eq(proxy.proxy_host)
    client.close
  end

it "connect to a website through SOCKS proxy" do
    host = URI.parse("https://ifconfig.me")
    client = Socksify::HTTPClient.new(host, ignore_env: true)
    proxy = Socksify::Proxy.new("socks://127.0.0.1:9150")
    client.set_proxy(proxy)
    response = client.exec("GET", "/ip")
    response.success?.should eq(true)
    # response.body.to_s.should eq(proxy.proxy_host)
    client.close
  end

end
