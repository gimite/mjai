require "mjai/with_fields"


module Mjai
    
    # Context of the game which affects hora yaku and points.
    class Context
        
        extend(WithFields)
        
        define_fields([
          :oya, :bakaze, :jikaze, :doras, :uradoras,
          :reach, :double_reach, :ippatsu,
          :rinshan, :haitei, :first_turn, :chankan,
        ])
        
        def initialize(fields)
          @fields = fields
        end
        
        def fanpai_fan(pai)
          if pai.sangenpai?
            return 1
          else
            fan = 0
            fan += 1 if pai == self.bakaze
            fan += 1 if pai == self.jikaze
            return fan
          end
        end
        
    end
    
end
