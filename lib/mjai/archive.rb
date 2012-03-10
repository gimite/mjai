module Mjai
    
    autoload(:TenhouArchive, "mjai/tenhou_archive")
    autoload(:MjsonArchive, "mjai/mjson_archive")
    
    class Archive
        
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
        
    end
    
end
