require "mjai/game"


module Mjai
    
    autoload(:TenhouArchive, "mjai/tenhou_archive")
    autoload(:MjsonArchive, "mjai/mjson_archive")
    
    class Archive < Game
        
        def self.load(path)
          case File.extname(path)
            when ".mjlog"
              return TenhouArchive.new(path)
            when ".mjson"
              return MjsonArchive.new(path)
            else
              raise("unknown format")
          end
        end
        
        def initialize()
          super((0...4).map(){ PuppetPlayer.new() })
          @actions = nil
        end
        
        def each_action(&block)
          if block
            on_action(&block)
            play()
          else
            return enum_for(:each_action)
          end
        end
        
        def actions
          return @actions ||= self.each_action.to_a()
        end
        
        def expect_response_from?(player)
          return false
        end
        
        def inspect
          return '#<%p:path=%p>' % [self.class, self.path]
        end
        
    end
    
end
