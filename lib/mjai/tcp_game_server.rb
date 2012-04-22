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
          @server = TCPServer.open(params[:host], params[:port])
          @players = []
          @mutex = Mutex.new()
        end
        
        def run()
          puts("Listening on host %s, port %d" % [@params[:host], @params[:port]])
          puts("URL: %s" % self.server_url)
          puts("Waiting for 4 players...")
          @pids = []
          begin
            start_default_players()
            while true
              Thread.new(@server.accept()) do |socket|
                socket.sync = true
                socket.puts(JSON.dump({
                    "type" => "hello",
                    "protocol" => "mjsonp",
                    "protocol_version" => 1,
                }))
                message = JSON.parse(socket.gets())
                error = nil
                if message["type"] == "join" && message["name"] && message["room"]
                  if message["room"] == @params[:room]
                    @mutex.synchronize() do
                      if @players.size < 4
                        @players.push(TCPPlayer.new(socket, message["name"]))
                        puts("Waiting for %s more players..." % (4 - @players.size))
                        if @players.size == 4
                          Thread.new(){ play_game() }
                        end
                      else
                        error = "The room is busy. Retry after a while."
                      end
                    end
                  else
                    error = "No such room. Available room: %s" % @params[:room]
                  end
                else
                  error = "Expected e.g. %s" %
                      JSON.dump({"type" => "join", "name" => "noname", "room" => @params[:room]})
                end
                if error
                  socket.puts(JSON.dump({"type" => "error", "message" => error}))
                  socket.close()
                end
              end
            end
          rescue Exception => ex
            for pid in @pids
              begin
                Process.kill("INT", pid)
              rescue => ex2
                p ex2
              end
            end
            raise(ex)
          end
        end
        
        def play_game()
          if @params[:log_dir]
            mjson_path = "%s/%s.mjson" % [@params[:log_dir], Time.now.strftime("%Y-%m-%d-%H%M%S")]
          else
            mjson_path = nil
          end
          maybe_open(mjson_path, "w") do |mjson_out|
            mjson_out.sync = true if mjson_out
            @game = ActiveGame.new(@players)
            @game.game_type = @params[:game_type]
            @game.on_action() do |action|
              mjson_out.puts(action.to_json()) if mjson_out
              @game.dump_action(action)
            end
            @game.play()
          end
          for player in @players
            player.close()
          end
          for pid in @pids
            Process.waitpid(pid)
          end
          @pids = []
          @players = []
          if @params[:repeat]
            start_default_players()
          else
            exit()
          end
        end
        
        def server_url
          return "mjsonp://localhost:%d/%s" % [@params[:port], @params[:room]]
        end
        
        def start_default_players()
          for command in @params[:player_commands]
            command += " " + self.server_url
            puts(command)
            @pids.push(spawn(command))
          end
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
