# socksify-cr

Little Proxy client library for HTTP and SOCKS type

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     socksify:
       github: dakad/socksify-cr
   ```

2. Run `shards install`

## Usage

```crystal
require "socksify"

Socksify::Proxy.configure do |config|
   config.timeout_sec = 60
   config.max_retries = 2
end

host = URI.parse "https://example.com"
client = Socksify::HTTPClient.new(host, ignore_env: true)
proxy = Socksify::Proxy.new "http://127.0.0.1:18080"
proxy = Socksify::Proxy.new "socks5://127.0.0.1:9150"
client.set_proxy proxy
response = client.exec("GET", "/me")
client close
```

### Configure the Proxy connection
```crystal
require "socksify"

Socksify::Proxy.configure do |config|
   config.connect_timeout_sec = 60
   config.timeout_sec = 30
   config.max_retries = 2
end
```

* _connect_timeout_sec_: Limit the connection timeout on the proxy socket and HTTT::Client 
* _timeout_sec_: Other timeout (dns,read,write) 
* _max_retries_: Number of retries after error during TCPSocket creation or connection

## Development

Run ``crystal spec`` to run project's tests. To run and setup a real SOCKS server, we can use this [lib under docker](https://github.com/PeterDaveHello/tor-socks-proxy)

You can also manually run the examples under ``/examples``

To debug, follow this [link's guide](https://github.com/amberframework/docs/blob/29560f6/examples/crystal-debug.md) to setup gdb/lldb with VSCode.

For Vim, run the commands below:

1. ``shards build --debug --progress simple`` to build for debug one the specified target in ``shards.yml``

2. Or ``crystal build --debug --progress -o bin/simple examples/simple.cr`` build your file directly

3. ``gdb bin/simple`` to debug the compiled code

4. ``(gdb) run`` Will run the compiled source and maybe throw an error in the console, but don't mind :)

``
Program received signal SIGSEGV, Segmentation fault.
0x000055555589365e in GC_find_limit_with_bound ()
``
5. ``(gdb) continue``
6. Here is a [gdb cheatsheet's link](https://gist.github.com/Dakad/7fedabcbb3f9b2cc2d1af76c665a4839)

## Contributing

1. Fork it (<https://github.com/Dakad/socksify-cr>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Merge Request

## Contributors

- [@DakaD](https://github.com/your-github-user) - creator and maintainer
