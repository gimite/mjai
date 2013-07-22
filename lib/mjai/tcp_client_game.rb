require "socket"
require "uri"

require "rubygems"
require "json"

require "mjai/game"
require "mjai/action"
require "mjai/puppet_player"


module Mjai
    
    class TCPClientGame < Game
        
        def initialize(params)
          super()
          @params = params
        end
        
        def play()
          uri = URI.parse(@params[:url])
          TCPSocket.open(uri.host, uri.port) do |socket|
            socket.sync = true
            socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
            socket.each_line() do |line|
              puts("<-\t%s" % line.chomp())
              action_json = line.chomp()
              action_obj = JSON.parse(action_json)
              case action_obj["type"]
                when "hello"
                  response_json = JSON.dump({
                      "type" => "join",
                      "name" => @params[:name],
                      "room" => uri.path.slice(/^\/(.*)$/, 1),
                  })
                when "error"
                  break
                else
                  if action_obj["type"] == "start_game"
                    @my_id = action_obj["id"]
                    self.players = Array.new(4) do |i|
                      i == @my_id ? @params[:player] : PuppetPlayer.new()
                    end
                  end
                  action = Action.from_json(action_json, self)
                  responses = do_action(action)
                  break if action.type == :end_game
                  response = responses && responses[@my_id]
                  response_json = response ? response.to_json() : JSON.dump({"type" => "none"})
              end
              puts("->\t%s" % response_json)
              socket.puts(response_json)
            end
          end
        end
        
        def expect_response_from?(player)
          return player.id == @my_id
        end
        
    end
    
end
