require "./mahjong"


for path in ARGV
  archive = Mjai::Archive.load(path)
  archive.on_action() do |action|
    archive.dump_action(action)
  end
  archive.play()
end
