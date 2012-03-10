require "mjai/player"
require "mjai/shanten_analysis"
require "mjai/pai"


module Mjai
    
    class ShantenPlayer < Player
        
        USE_FURO = false
        
        def respond_to_action(action)
          
          if action.actor == self
            
            case action.type
              
              when :tsumo, :chi, :pon, :reach
                shanten = ShantenAnalysis.new(self.tehais).shanten
                if action.type == :tsumo
                  case shanten
                    when -1
                      return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
                    when 0
                      return create_action({:type => :reach}) if !self.reach?
                  end
                  for pai in self.tehais
                    if self.tehais.select(){ |tp| tp == pai }.size >= 4
                      #@game.last = true
                      return create_action({:type => :ankan, :consumed => [pai] * 4})
                    end
                  end
                  pon = self.furos.find(){ |f| f.type == :pon && f.taken == action.pai }
                  if pon
                    #@game.last = true
                    return create_action(
                        {:type => :kakan, :pai => action.pai, :consumed => [action.pai] * 3})
                  end
                end
                sutehai = self.tehais[-1]
                (self.tehais.size - 1).downto(0) do |i|
                  remains = self.tehais.dup()
                  remains.delete_at(i)
                  if ShantenAnalysis.new(remains, shanten).shanten == shanten
                    sutehai = self.tehais[i]
                    break
                  end
                end
                p [:shanten, @id, shanten]
                return create_action({:type => :dahai, :pai => sutehai})
                
            end
            
          else  # action.actor != self
            
            case action.type
              when :dahai
                if ShantenAnalysis.new(self.tehais + [action.pai]).shanten == -1
                  return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
                elsif USE_FURO
                  if self.tehais.select(){ |pai| pai == action.pai }.size >= 3
                    #@game.last = true
                    return create_action({
                      :type => :daiminkan,
                      :pai => action.pai,
                      :consumed => [action.pai] * 3,
                      :target => action.actor
                    })
                  elsif self.tehais.select(){ |pai| pai == action.pai }.size >= 2
                    return create_action({
                      :type => :pon,
                      :pai => action.pai,
                      :consumed => [action.pai] * 2,
                      :target => action.actor
                    })
                  elsif (action.actor.id + 1) % 4 == self.id && action.pai.type != "t"
                    for i in 0...3
                      consumed = (((-i)...(-i + 3)).to_a() - [0]).map() do |j|
                        Pai.new(action.pai.type, action.pai.number + j)
                      end
                      if consumed.all?(){ |pai| self.tehais.index(pai) }
                        return create_action({
                          :type => :chi,
                          :pai => action.pai,
                          :consumed => consumed,
                          :target => action.actor,
                        })
                      end
                    end
                  end
                end
            end
            
          end
          
          return nil
        end
        
    end
    
end
