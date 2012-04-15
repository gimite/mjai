require "mjai/player"
require "mjai/action"


module Mjai
    
    class TCPPlayer < Player
        
        def initialize(socket, name)
          super()
          @socket = socket
          self.name = name
        end
        
        def respond_to_action(action)
          @socket.puts(action.to_json())
          response = Action.from_json(@socket.gets().chomp(), self.game)
          return response.type == :none ? nil : response
        end
        
    end
    
end
