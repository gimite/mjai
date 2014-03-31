require "mjai/with_fields"
require "mjai/mentsu"


module Mjai
    
    # 副露
    class Furo
        
        extend(WithFields)
        
        # type: :chi, :pon, :daiminkan, :kakan, :ankan
        define_fields([:type, :taken, :consumed, :target])
        
        FURO_TYPE_TO_MENTSU_TYPE = {
          :chi => :shuntsu,
          :pon => :kotsu,
          :daiminkan => :kantsu,
          :kakan => :kantsu,
          :ankan => :kantsu,
        }
        
        def initialize(fields)
          @fields = fields
        end
        
        def kan?
          return FURO_TYPE_TO_MENTSU_TYPE[self.type] == :kantsu
        end
        
        def pais
          return (self.taken ? [self.taken] : []) + self.consumed
        end
        
        def to_mentsu()
          return Mentsu.new({
              :type => FURO_TYPE_TO_MENTSU_TYPE[self.type],
              :pais => self.pais,
              :visibility => self.type == :ankan ? :an : :min,
          })
        end
        
        def to_s()
          if self.type == :ankan
            return '[# %s %s #]' % self.consumed[0, 2]
          else
            return "[%s(%p)/%s]" % [
                self.taken,
                self.target && self.target.id,
                self.consumed.join(" "),
            ]
          end
        end
        
        def inspect
          return "\#<%p %s>" % [self.class, to_s()]
        end
        
    end
    
end
