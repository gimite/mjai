require "optparse"

require "mjai/tcp_game_server"
require "mjai/tcp_client_game"
require "mjai/tsumogiri_player"
require "mjai/shanten_player"


module Mjai
    
    class MjaiCommand
        
        def self.execute(argv)
          Thread.abort_on_exception = true
          action = argv.shift()
          opts = OptionParser.getopts(argv, "",
              "port:", "host:", "game_type:one_kyoku", "players:", "repeat", "name:")
          case action
            when "server"
              raise("--port missing") if !opts["port"]
              server = TCPGameServer.new({
                  :host => opts["host"],
                  :port => opts["port"].to_i(),
                  :game_type => opts["game_type"].intern,
                  :player_specs => (opts["players"] || "").split(/,/),
                  :repeat => opts["repeat"],
              })
              server.run()
            when "tsumogiri", "shanten"
              case action
                when "tsumogiri"
                  player = TsumogiriPlayer.new()
                when "shanten"
                  player = Mjai::ShantenPlayer.new({:use_furo => false})
                else
                  raise("should not happen")
              end
              game = TCPClientGame.new({
                  :player => player,
                  :host => opts["host"],
                  :port => opts["port"].to_i(),
                  :name => opts["name"],
              })
              game.play()
            else
              raise("unknown action")
          end
        end
        
    end
    
end
