require "json"

$stdin.sync = true
$stdout.sync = true

id = nil
$stdin.each_line() do |line|
  $stderr.puts("< %s" % line.chomp())
  action = JSON.parse(line.chomp())
  if action["type"] == "start_game"
    id = action["id"]
    response = {"type" => "none"}
  elsif action["type"] == "tsumo" && action["actor"] == id
    response = {"type" => "dahai", "actor" => id, "target" => id, "pai" => action["pai"]}
  else
    response = {"type" => "none"}
  end
  $stderr.puts("> %s" % JSON.dump(response))
  puts(JSON.dump(response))
end
