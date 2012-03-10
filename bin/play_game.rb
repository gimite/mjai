$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "optparse"

require "mjai/active_game"
require "mjai/statistical_player"


opts = OptionParser.getopts("")
game = Mjai::ActiveGame.new((0...4).map(){ Mjai::StatisticalPlayer.new() })
game.game_type = :tonnan
game.on_action() do |action|
  game.dump_action(action)
end
game.play()
