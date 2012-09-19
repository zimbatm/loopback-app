#!/usr/bin/env ruby
#
# A small app that returns back what we got from the HTTP request
#

require 'thread'
require 'socket'
require 'timeout'
require 'securerandom'

def get_unique_client_id
  SecureRandom.random_number(2**64).to_s(32)
end

def handle_client(client)
  id = get_unique_client_id
  log = ->(*a) { p [id, *a] }
  log["New client", client]
  client.binmode

  timeout(5) do
    request = [""]
    while !request.join.index("\r\n\r\n")
      request << client.sysread(1024)
    end

    body = request.join

    client.write "HTTP/1.0 200 OK\r\nContent-Length: #{body.bytesize}\r\nContent-Type: text/plain\r\n\r\n#{body}"
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
