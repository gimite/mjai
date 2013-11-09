require "mjai/player"
require "mjai/shanten_analysis"
require "mjai/pai"


module Mjai
    
    class ShantenPlayer < Player
        
        def initialize(params)
          super()
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
                    return create_action({:type => :dahai, :pai => action.pai, :tsumogiri => true})
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
                  return create_action({:type => :dahai, :pai => action.pai, :tsumogiri => true})
                end
                
                # Ankan, kakan
                furo_actions = self.possible_furo_actions
                if !furo_actions.empty?
                  return furo_actions[0]
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
                #log("sutehai_cands = %p" % [sutehai_cands])
                sutehai = sutehai_cands[rand(sutehai_cands.size)]
                tsumogiri = [:tsumo, :reach].include?(action.type) && sutehai == self.tehais[-1]
                return create_action({:type => :dahai, :pai => sutehai, :tsumogiri => tsumogiri})
                
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
                  furo_actions = self.possible_furo_actions
                  if !furo_actions.empty?
                    return furo_actions[0]
                  end
                end
            end
            
          end
          
          return nil
        end
        
    end
    
end
