require "mjai/game"
require "mjai/puppet_player"
require "mjai/action"


module Mjai
    
    class MjsonArchive < Game
        
        def initialize(path)
          super((0...4).map(){ PuppetPlayer.new() })
          @path = path
        end
        
        attr_reader(:path)
        
        def play()
          File.foreach(@path) do |line|
            do_action(Action.from_json(line.chomp(), self))
          end
        end
        
        def expect_response_from?(player)
          return false
        end
        
    end
    
end
