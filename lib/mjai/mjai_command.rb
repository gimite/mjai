require "optparse"

require "mjai/tcp_game_server"
require "mjai/tcp_client_game"
require "mjai/tsumogiri_player"
require "mjai/shanten_player"


module Mjai
    
    class MjaiCommand
        
        def self.execute(command_name, argv)
          
          Thread.abort_on_exception = true
          case command_name
            
            when "mjai"
              
              action = argv.shift()
              opts = OptionParser.getopts(argv, "",
                  "port:11600", "host:127.0.0.1", "room:default", "game_type:one_kyoku",
                  "repeat")
              case action
                when "server"
                  raise("--port missing") if !opts["port"]
                  server = TCPGameServer.new({
                      :host => opts["host"],
                      :port => opts["port"].to_i(),
                      :room => opts["room"],
                      :game_type => opts["game_type"].intern,
                      :player_commands => argv,
                      :repeat => opts["repeat"],
                  })
                  server.run()
                else
                  raise("unknown action")
              end
              
            when /^mjai-(.+)$/
              
              player_type = $1
              case player_type
                when "tsumogiri"
                  player = TsumogiriPlayer.new()
                when "shanten"
                  player = Mjai::ShantenPlayer.new({:use_furo => false})
                else
                  raise("unknown action")
              end
              opts = OptionParser.getopts(argv, "", "name:")
              url = ARGV.shift()
              game = TCPClientGame.new({
                  :player => player,
                  :url => url,
                  :name => opts["name"] || player_type,
              })
              game.play()
              
            else
              raise("should not happen")
          
          end
          
        end
        
    end
    
end
