require "optparse"

require "mjai/tcp_game_server"
require "mjai/tcp_client_game"
require "mjai/tsumogiri_player"
require "mjai/shanten_player"
require "mjai/file_converter"


module Mjai
    
    class MjaiCommand
        
        def self.execute(command_name, argv)
          
          Thread.abort_on_exception = true
          case command_name
            
            when "mjai"
              
              action = argv.shift()
              opts = OptionParser.getopts(argv, "",
                  "port:11600", "host:127.0.0.1", "room:default", "game_type:one_kyoku",
                  "games:1", "repeat", "log_dir:")
              case action
                when "server"
                  $stdout.sync = true
                  if opts["repeat"]
                    num_games = 1.0/0.0
                  else
                    num_games = opts["games"].to_i()
                  end
                  server = TCPGameServer.new({
                      :host => opts["host"],
                      :port => opts["port"].to_i(),
                      :room => opts["room"],
                      :game_type => opts["game_type"].intern,
                      :player_commands => argv,
                      :num_games => num_games,
                      :log_dir => opts["log_dir"],
                  })
                  server.run()
                when "convert"
                  FileConverter.new().convert(argv.shift(), argv.shift())
                else
                  $stderr.puts(
                      "Usage:\n" +
                      "  #{$PROGRAM_NAME} server --port=PORT " +
                          "[PLAYER1_COMMAND] [PLAYER2_COMMAND] [...]\n" +
                      "  #{$PROGRAM_NAME} convert hoge.mjson hoge.html\n" +
                      "  #{$PROGRAM_NAME} convert hoge.mjlog hoge.mjson\n")
                  exit(1)
              end
              
            when /^mjai-(.+)$/
              
              $stdout.sync = true
              player_type = $1
              opts = OptionParser.getopts(argv, "", "t:", "name:")
              url = ARGV.shift()
              
              if !url
                $stderr.puts(
                    "Usage:\n" +
                    "  #{$PROGRAM_NAME} mjsonp://localhost:11600/default\n")
                exit(1)
              end
              case player_type
                when "tsumogiri"
                  player = TsumogiriPlayer.new()
                when "shanten"
                  player = Mjai::ShantenPlayer.new({:use_furo => opts["t"] == "f"})
                else
                  raise("should not happen")
              end
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
