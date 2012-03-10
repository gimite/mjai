require "mjai/archive"
require "mjai/puppet_player"
require "mjai/action"


module Mjai
    
    class MjsonArchive < Archive
        
        def initialize(path)
          super()
          @path = path
        end
        
        attr_reader(:path)
        
        def play()
          File.foreach(@path) do |line|
            do_action(Action.from_json(line.chomp(), self))
          end
        end
        
    end
    
end
