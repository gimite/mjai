require "./mahjong"


for path in ARGV
  archive = Archive.new(path)
  archive.play_game() do |action|
    archive.dump_action(action)
  end
end
