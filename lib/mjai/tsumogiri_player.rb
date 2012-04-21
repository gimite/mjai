require "mjai/player"


module Mjai
    
    class TsumogiriPlayer < Player
        
        def respond_to_action(action)
          case action.type
            when :tsumo, :chi, :pon
              if action.actor == self
                return create_action({:type => :dahai, :pai => self.tehais[-1], :tsumogiri => true})
              end
          end
          return nil
        end
        
    end
    
end
