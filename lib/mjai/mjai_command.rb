require "optparse"

require "mjai/tcp_game_server"


module Mjai
    
    class MjaiCommand
        
        def self.execute(argv)
          Thread.abort_on_exception = true
          action = argv.shift()
          opts = OptionParser.getopts(argv, "",
              "port:", "host:", "game_type:one_kyoku", "players:", "repeat")
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
            else
              raise("unknown action")
          end
        end
        
    end
    
end
