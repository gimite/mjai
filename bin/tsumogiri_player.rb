require "socket"
require "json"
require "uri"


def send(response)
  $stderr.puts("> %s" % JSON.dump(response))
  @socket.puts(JSON.dump(response))
end

uri = URI.parse(ARGV[0])
@socket = TCPSocket.new(uri.host, uri.port)
@socket.sync = true
id = nil
@socket.each_line() do |line|
  $stderr.puts("< %s" % line.chomp())
  action = JSON.parse(line.chomp())
  if action["type"] == "hello"
    response = {"type" => "join", "name" => "tsumogiri", "room" => uri.path.slice(/^\/(.*)$/, 1)}
  elsif action["type"] == "start_game"
    id = action["id"]
    response = {"type" => "none"}
  elsif action["type"] == "end_game"
    break
  elsif action["type"] == "tsumo" && action["actor"] == id
    response = {"type" => "dahai", "actor" => id, "target" => id, "pai" => action["pai"]}
  elsif action["type"] == "error"
    break
  else
    response = {"type" => "none"}
  end
  send(response)
end
