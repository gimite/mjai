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
        end
        
        def expect_response_from?(player)
          return false
        end
        
    end
    
end
