require "./mahjong"
require "./min_required_pais"


class StatisticalPlayer < Player
    
    def respond_to_action(action)
      case action.type
        
        when :tsumo, :chi, :pon
          if action.actor == self
            
            current_shanten = ShantenCounter.new(self.tehais, nil, [:normal]).shanten
            if action.type == :tsumo && current_shanten == -1
              return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
            end
            p [:shanten, current_shanten]
            
            visible = []
            visible += self.board.doras
            visible += self.tehais
            for player in self.board.players
              visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
            end
            visible_set = to_pai_set(visible)
            
            max_prob = -1.0/0.0
            max_pai_index = nil
            for i in 0...self.tehais.size
              remains = self.tehais.dup()
              remains.delete_at(i)
              if ShantenCounter.new(remains, current_shanten, [:normal]).shanten != current_shanten
                next
              end
              prob = get_hora_prob(remains, visible_set, visible.size)
              p [:hora_prob, self.tehais[i], prob]
              if prob > max_prob
                max_prob = prob
                max_pai_index = i
              end
            end
            p [:dahai, self.tehais[max_pai_index]]
            #gets()
            
            return create_action({:type => :dahai, :pai => self.tehais[max_pai_index]})
            
          end
          
        when :dahai
          if action.actor != self
            if ShantenCounter.new(self.tehais + [action.pai], -1) == -1
              return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
            end
          end
          
      end
      
      return nil
    end
    
    def get_hora_prob(tehais, visible_set, num_visible)
      num_invisible = board.all_pais.size - num_visible
      num_tsumos = board.num_pipais / 4
      hora_prob = 0.0
      for required_pais in MinRequiredPais.new(tehais).candidates
        all_tsumo_prob = 1.0
        for pai in required_pais
          num_same_invisible = 4 - visible_set[pai]
          pai_tsumo_prob = 1 -
              num_permutations(num_invisible - num_same_invisible, num_tsumos) /
              num_permutations(num_invisible, num_tsumos).to_f()
          #p [:pai_tsumo_prob, pai, num_invisible, num_same_invisible, num_tsumos, pai_tsumo_prob]
          all_tsumo_prob *= pai_tsumo_prob
        end
        #p [:all_tsumo_prob, required_pais, all_tsumo_prob]
        hora_prob += all_tsumo_prob
      end
      return hora_prob
    end
    
    def num_permutations(n, m)
      return ((n - m + 1)..n).inject(1, :*)
    end
    
    def to_pai_set(pais)
      pai_set = Hash.new(0)
      for pai in pais
        pai_set[pai.remove_red()] += 1
      end
      return pai_set
    end
    
end
