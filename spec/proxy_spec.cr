require "./spec_helper.cr"
# require "../src/lib/proxy"
# require "../src/lib/http_client"

describe Socksify::HTTPClient do

  it "connect to a website and get a response" do
    host = URI.parse("https://ifconfig.me")
    response = Socksify::HTTPClient.new(host) do |client|
      client.exec("GET", "/all")
    end
    p! response
    response.success?.should eq(true)
  end

  # it "connect to a website and get a response using explicit proxy" do
  #   host = URI.parse("https://github.com/")
  #   client = Socksify::HTTPClient.new(host, ignore_env: true)
  #   proxy = Socksify::Proxy.new("localhost", 22222)
  #   client.set_proxy(proxy)
  #   response = client.exec("GET", "/")
  #   response.success?.should eq(true)
  #   client.close
  # end

end
