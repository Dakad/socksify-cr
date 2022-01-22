require "./spec_helper"

describe Socksify do

  it "should resolve a domain to IP" do
    SpecHelper.enable_socks

    dns_hosts = ["one.one.one.one", ""]
    dns_ip = ["1.1.1.1", "8.8.8.8"]

    dns_hosts.each_with_index do |host, i|
      ip_address = Socksify.resolve host
      ip_address.should eq dns_ip[i]
    end

  end
end
