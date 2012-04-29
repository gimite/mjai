#!/usr/bin/env ruby

require "socket"
require "json"
require "uri"


uri = URI.parse(ARGV[0])
socket = TCPSocket.new(uri.host, uri.port)
socket.sync = true
id = nil

socket.each_line() do |line|
  
  $stderr.puts("<-\t%s" % line.chomp())
  action = JSON.parse(line.chomp())
  case action["type"]
    when "hello"
      response = {
          "type" => "join",
          "name" => "tsumogiri",
          "room" => uri.path[1..-1],
      }
    when "start_game"
      id = action["id"]
      response = {"type" => "none"}
    when "end_game"
      break
    when "tsumo"
      if action["actor"] == id
        response = {
            "type" => "dahai",
            "actor" => id,
            "pai" => action["pai"],
            "tsumogiri" => true,
        }
      else
        response = {"type" => "none"}
      end
    when "error"
      break
    else
      response = {"type" => "none"}
  end
  $stderr.puts("->\t%s" % JSON.dump(response))
  socket.puts(JSON.dump(response))
  
end
