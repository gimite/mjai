require "mjai/with_fields"


module Mjai
    
    # 副露
    class Furo
        
        extend(WithFields)
        
        define_fields([:type, :taken, :consumed, :target])
        
        def initialize(fields)
          @fields = fields
        end
        
        def pais
          return (self.taken ? [self.taken] : []) + self.consumed
        end
        
        def to_s()
          if self.type == :ankan
            return '[# %s %s #]' % self.consumed[0, 2]
          else
            return "[%s(%d)/%s]" % [self.taken, self.target.id, self.consumed.join(" ")]
          end
        end
        
    end
    
end
