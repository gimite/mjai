require "timeout"

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
          return nil if action.type == :log
          @socket.puts(action.to_json())
          line = nil
          Timeout.timeout(60) do
            line = @socket.gets()
          end
          if line
            response = Action.from_json(line.chomp(), self.game)
            return response.type == :none ? nil : response
          else
            return nil
          end
        end
        
        def close()
          @socket.close()
        end
        
    end
    
end
