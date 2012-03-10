require "mjai/player"
require "mjai/action"


module Mjai
    
    class PipePlayer < Player
        
        def initialize(command)
          super()
          @io = IO.popen(command, "r+")
          @io.sync = true
        end
        
        def respond_to_action(action)
          @io.puts(action.to_json())
          response = Action.from_json(@io.gets().chomp(), self.game)
          return response.type == :none ? nil : response
        end
        
    end
    
end
