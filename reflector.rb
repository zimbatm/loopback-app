#!/usr/bin/env ruby
#
# A small app that returns back what we got from the HTTP request
#

require 'thread'
require 'socket'
require 'timeout'
require 'securerandom'
require 'cgi'

def get_unique_client_id
  SecureRandom.random_number(2**64).to_s(32)
end

CRLF = "\r\n"
CRLF2 = CRLF * 2
CRLF_HEX = ["0d", "0a"]

def hexwall(str)
  str.split(CRLF).map do |line|
    line.bytes.map{|b| "%02x" % b}.join(" ") + CRLF_HEX.join
  end.join(CRLF)
end

def handle_client(client)
  id = get_unique_client_id
  log = ->(*a) { p [id, *a] }
  log["New client", client]
  client.binmode

  timeout(5) do
    request = [""]
    while !request.join.index(CRLF2)
      line = client.sysread(1024)
      log[line]
      request << line
    end

    body = request.join
    content_type = 'text/plain'

    if body =~ /Accept:.*text\/html/
      content_type = 'text/html'
      body = <<-HTML_BODY
<!doctype html>
<meta charset="utf-8">
<title>Loopback</title>
<link rel="stylesheet" href="http://twitter.github.com/bootstrap/assets/css/bootstrap.css">
<style>
body{ padding: 2em; }
</style>
<h1>Loopback</h1>
<p>This is the exact request that my server got from the last hop:</p>
<pre>
#{CGI.escape_html body}
</pre>
<pre>
#{hexwall body}
</pre>
<footer>This service was coded by zimbatm ( <a href="http://0x2a.im">http://0x2a.im</a> ) and is hosted by <a href="http://heroku.com">Heroku</a></footer>
      HTML_BODY
    end

    client.write ['HTTP/1.0 200 OK', "Content-Length: #{body.bytesize}", "Content-Type: #{content_type}", "", body].join(CRLF)
  end
rescue Timeout::Error
  log[:client_timeout]
rescue => ex
  log[:error, ex, *ex.backtrace]
ensure
  client.close
end

def main(port)
  log = ->(*a) { p [:server, *a] }
  clients = ThreadGroup.new
  server = TCPServer.new port

  trap("INT") { server.close }
  trap("TERM") { server.close }

  log[:started, port: port]

  while !server.closed?
    Thread.new(server.accept) do |client|
      clients.add Thread.current
      handle_client client
    end
  end

rescue Errno::EBADF # getting when closing the server on accept
  log[:shutting_down]
ensure
  timeout(15) do
    while clients.list.any?
      sleep 1
    end
  end
  log[:bye]
end

if __FILE__ === $0
  if !ARGV[0]
    $stderr.puts "Port argument missing"
    $stderr.puts "Usage: #{File.basename(__FILE__)} <PORT>"
    exit 1
  end
  main(ARGV[0])
end
