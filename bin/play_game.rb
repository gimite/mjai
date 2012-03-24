$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "optparse"

require "mjai/active_game"
require "mjai/statistical_player"


opts = OptionParser.getopts("", "step")
game = Mjai::ActiveGame.new((0...4).map(){ Mjai::StatisticalPlayer.new() })
game.game_type = :one_kyoku
game.on_action() do |action|
  game.dump_action(action)
  if opts["step"] && action.actor == game.players[0] && action.type != :haipai
    gets()
  end
end
game.play()
