require "socket"
require "thread"

require "rubygems"
require "json"

require "mjai/active_game"
require "mjai/tcp_player"


module Mjai
    
    class TCPGameServer
        
        def initialize(params)
          @params = params
          if params[:host]
            @server = TCPServer.open(params[:host], params[:port])
          else
            @server = TCPServer.open(params[:port])
          end
          @players = []
          @mutex = Mutex.new()
        end
        
        def run()
          puts("listening")
          pids = []
          begin
            for spec in @params[:player_specs]
              case spec
                when "tsumogiri"
                  command = "ruby bin/tsumogiri_player.rb localhost %d" % @params[:port]
                else
                  raise("unknown spec")
              end
              puts(command)
              pids.push(spawn(command))
            end
            while true
              Thread.new(@server.accept()) do |socket|
                socket.sync = true
                socket.puts(JSON.dump({"type" => "hello"}))
                message = JSON.parse(socket.gets())
                if message["type"] != "hello"
                  raise("bad hello")
                end
                if !message["name"]
                  raise("name missing")
                end
                @mutex.synchronize() do
                  if @players.size < 4
                    @players.push(TCPPlayer.new(socket, message["name"]))
                    puts("%s players" % @players.size)
                    if @players.size == 4
                      Thread.new() do
                        @game = ActiveGame.new(@players)
                        @game.game_type = @params[:game_type]
                        @game.on_action() do |action|
                          @mjson_out.puts(action.to_json()) if @mjson_out
                          @game.dump_action(action)
                        end
                        @game.play()
                        for pid in pids
                          Process.waitpid(pid)
                        end
                        exit()
                      end
                    end
                  else
                    raise("too many players")
                  end
                end
              end
            end
          rescue Exception => ex
            for pid in pids
              begin
                Process.kill("INT", pid)
              rescue => ex2
                p ex2
              end
            end
            raise(ex)
          end
        end
        
    end
    
end
