require "mjai/player"
require "mjai/shanten_analysis"
require "mjai/pai"


module Mjai
    
    class ShantenPlayer < Player
        
        def initialize(params)
          @use_furo = params[:use_furo]
        end
        
        def respond_to_action(action)
          
          if action.actor == self
            
            case action.type
              
              when :tsumo, :chi, :pon, :reach
                
                current_shanten_analysis = ShantenAnalysis.new(self.tehais, nil, [:normal])
                current_shanten = current_shanten_analysis.shanten
                if can_hora?(current_shanten_analysis)
                  if @use_furo
                    return create_action({:type => :dahai, :pai => action.pai})
                  else
                    return create_action({
                        :type => :hora,
                        :target => action.actor,
                        :pai => action.pai,
                    })
                  end
                elsif can_reach?(current_shanten_analysis)
                  return create_action({:type => :reach})
                elsif self.reach?
                  return create_action({:type => :dahai, :pai => action.pai})
                end
                
                if action.type == :tsumo
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
                
                sutehai_cands = []
                for pai in self.possible_dahais
                  remains = self.tehais.dup()
                  remains.delete_at(self.tehais.index(pai))
                  if ShantenAnalysis.new(remains, current_shanten, [:normal]).shanten ==
                      current_shanten
                    sutehai_cands.push(pai)
                  end
                end
                if sutehai_cands.empty?
                  sutehai_cands = self.possible_dahais
                end
                p [:sutehai_cands, sutehai_cands]
                return create_action({:type => :dahai, :pai => sutehai_cands.sample})
                
            end
            
          else  # action.actor != self
            
            case action.type
              when :dahai
                if self.can_hora?
                  if @use_furo
                    return nil
                  else
                    return create_action({
                        :type => :hora,
                        :target => action.actor,
                        :pai => action.pai,
                    })
                  end
                elsif @use_furo
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
