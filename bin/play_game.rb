$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "optparse"

require "mjai/active_game"
require "mjai/statistical_player"
require "mjai/shanten_player"


PLAYER_CLASS_MAP = {
  "shanten" => Mjai::ShantenPlayer,
  "statistical" => Mjai::StatisticalPlayer,
}

def maybe_open(path, mode, &block)
  if path
    open(path, mode, &block)
  else
    yield(nil)
  end
end

$stdout.sync = true
opts = OptionParser.getopts("",
    "step",
    "players:stat_ppr,stat_ppr,stat_ppr,stat_ppr",
    "repeat:1",
    "game_type:one_kyoku",
    "output_mjson:",
    "srand:")
if opts["srand"]
  srand(opts["srand"].to_i())
end
players = []
for s in opts["players"].split(/,/)
  case s
    when "shanten"
      player = Mjai::ShantenPlayer.new({:use_furo => false})
    when "shanten_f"
      player = Mjai::ShantenPlayer.new({:use_furo => true})
    when "stat_ppr"
      player = Mjai::StatisticalPlayer.new({:score_type => :progress_prob})
    when "stat_ept"
      player = Mjai::StatisticalPlayer.new({:score_type => :expected_points})
    else
      raise("unknown player")
  end
  player.name = s
  players.push(player)
end
totals = Hash.new(0)
maybe_open(opts["output_mjson"], "w") do |mjson_out|
  opts["repeat"].to_i().times() do |i|
    game = Mjai::ActiveGame.new(players.shuffle())
    game.game_type = opts["game_type"].intern
    game.on_action() do |action|
      mjson_out.puts(action.to_json()) if mjson_out
      game.dump_action(action)
      if opts["step"] && action.actor == game.players[0] && action.type != :haipai
        gets()
      end
    end
    game.play()
    puts("game %d: %s" % [i, players.map(){ |pl| "%s:%d" % [pl.name, pl.points] }.join(" ")])
    for player in players
      totals[player] += player.points
    end
    puts("average: %s" %
        players.map(){ |pl| "%s:%d" % [pl.name, totals[pl].to_f() / (i + 1)] }.join(" "))
  end
end
