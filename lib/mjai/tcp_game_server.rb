require "socket"
require "thread"

require "rubygems"
require "json"

require "mjai/tcp_player"


module Mjai
    
    class TCPGameServer
        
        class LocalError < StandardError
        end

        def initialize(params)
          @params = params
          @server = TCPServer.open(params[:host], params[:port])
          @players = []
          @mutex = Mutex.new()
          @num_finished_games = 0
        end
        
        attr_reader(:params, :players, :num_finished_games)
        
        def run()
          puts("Listening on host %s, port %d" % [@params[:host], self.port])
          puts("URL: %s" % self.server_url)
          puts("Waiting for %d players..." % self.num_tcp_players)
          @pids = []
          begin
            start_default_players()
            while true
              Thread.new(@server.accept()) do |socket|
                error = nil
                begin
                  socket.sync = true
                  socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
                  send(socket, {
                      "type" => "hello",
                      "protocol" => "mjsonp",
                      "protocol_version" => 3,
                  })
                  line = socket.gets()
                  if !line
                    raise(LocalError, "Connection closed")
                  end
                  puts("server <- player ?\t#{line}")
                  message = JSON.parse(line)
                  if message["type"] != "join" || !message["name"] || !message["room"]
                    raise(LocalError, "Expected e.g. %s" %
                        JSON.dump({"type" => "join", "name" => "noname", "room" => @params[:room]}))
                  end
                  if message["room"] != @params[:room]
                    raise(LocalError, "No such room. Available room: %s" % @params[:room])
                  end
                  @mutex.synchronize() do
                    if @players.size >= self.num_tcp_players
                      raise(LocalError, "The room is busy. Retry after a while.")
                    end
                    @players.push(TCPPlayer.new(socket, message["name"]))
                    puts("Waiting for %s more players..." % (self.num_tcp_players - @players.size))
                    if @players.size == self.num_tcp_players
                      Thread.new(){ process_one_game() }
                    end
                  end
                rescue JSON::ParserError => ex
                  error = "JSON syntax error: %s" % ex.message
                rescue SystemCallError => ex
                  error = ex.message
                rescue LocalError => ex
                  error = ex.message
                end
                if error
                  begin
                    send(socket, {"type" => "error", "message" => error})
                    socket.close()
                  rescue SystemCallError
                  end
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
        
        def process_one_game()
          
          game = nil
          success = false
          begin
            (game, success) = play_game(@players)
          rescue => ex
            print_backtrace(ex)
          end
          
          begin
            for player in @players
              player.close()
            end
          rescue => ex
            print_backtrace(ex)
          end
          
          begin
            for pid in @pids
              Process.waitpid(pid)
            end
          rescue => ex
            print_backtrace(ex)
          end
          
          @num_finished_games += 1
          
          if success
            on_game_succeed(game)
          else
            on_game_fail(game)
          end
          puts()
          
          @pids = []
          @players = []
          if @num_finished_games >= @params[:num_games]
            exit()
          else
            start_default_players()
          end
          
        end
        
        def server_url
          return "mjsonp://localhost:%d/%s" % [self.port, @params[:room]]
        end
        
        def port
          return @server.addr[1]
        end
        
        def start_default_players()
          for command in @params[:player_commands]
            command += " " + self.server_url
            puts(command)
            @pids.push(fork(){ exec(command) })
          end
        end
        
        def send(socket, hash)
          line = JSON.dump(hash)
          puts("server -> player ?\t#{line}")
          socket.puts(line)
        end
        
        def print_backtrace(ex, io = $stderr)
          io.printf("%s: %s (%p)\n", ex.backtrace[0], ex.message, ex.class)
          for s in ex.backtrace[1..-1]
            io.printf("        %s\n", s)
          end
        end
        
    end
    
end
