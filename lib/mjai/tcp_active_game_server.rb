require "mjai/active_game"
require "mjai/tcp_game_server"


module Mjai
    
    class TCPActiveGameServer < TCPGameServer
        
        Statistics = Struct.new(:num_games, :total_rank, :total_score)
        
        def initialize(params)
          super
          @name_to_stat = {}
        end
        
        def num_tcp_players
          return 4
        end
        
        def play_game(players)
          
          if self.params[:log_dir]
            mjson_path = "%s/%s.mjson" % [self.params[:log_dir], Time.now.strftime("%Y-%m-%d-%H%M%S")]
          else
            mjson_path = nil
          end
          
          maybe_open(mjson_path, "w") do |mjson_out|
            mjson_out.sync = true if mjson_out
            game = ActiveGame.new(players)
            game.game_type = self.params[:game_type]
            game.on_action() do |action|
              mjson_out.puts(action.to_json()) if mjson_out
              game.dump_action(action)
            end
            success = game.play()
            return [game, success]
          end
          
        end
        
        def on_game_succeed(game)
          puts("game %d: %s" % [
              self.num_finished_games,
              game.ranked_players.map(){ |pl| "%s:%d" % [pl.name, pl.score] }.join(" "),
          ])
          for player in self.players
            @name_to_stat[player.name] ||= Statistics.new(0, 0, 0)
            @name_to_stat[player.name].num_games += 1
            @name_to_stat[player.name].total_score += player.score
            @name_to_stat[player.name].total_rank += player.rank
          end
          names = self.players.map(){ |pl| pl.name }.sort().uniq()
          print("Average rank:")
          for name in names
            print(" %s:%.3f" % [
                name,
                @name_to_stat[name].total_rank.to_f() / @name_to_stat[name].num_games,
            ])
          end
          puts()
          print("Average score:")
          for name in names
            print(" %s:%d" % [
                name,
                @name_to_stat[name].total_score.to_f() / @name_to_stat[name].num_games,
            ])
          end
        end
        
        def on_game_fail(game)
          puts("game %d: Ended with error" % self.num_finished_games)
        end
        
        def maybe_open(path, mode, &block)
          if path
            open(path, mode, &block)
          else
            yield(nil)
          end
        end
        
    end
    
end
