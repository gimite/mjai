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
            for pai in self.tehais.uniq()
              idx = self.tehais.index(pai)
              remains = self.tehais.dup()
              remains.delete_at(idx)
              shanten = ShantenCounter.new(remains, current_shanten, [:normal])
              if shanten.shanten != current_shanten
                next
              end
              prob = get_hora_prob(shanten, visible_set, visible.size)
              p [:hora_prob, pai, prob]
              if prob > max_prob
                max_prob = prob
                max_pai_index = idx
              end
            end
            p [:dahai, self.tehais[max_pai_index]]
            #if self.id == 0
            #  print("> ")
            #  gets()
            #end
            
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
    
    def get_hora_prob(shanten, visible_set, num_visible)
      num_invisible = board.all_pais.size - num_visible
      num_tsumos = board.num_pipais / 4
      no_hora_prob = 1.0
      num_allowed_extra = shanten.shanten <= 3 ? 1 : 0
      for required_pais in MinRequiredPais.new(shanten, num_allowed_extra).candidates
        all_tsumo_prob = 1.0
        for pai in required_pais
          num_same_invisible = 4 - visible_set[pai]
          pai_tsumo_prob = 1.0 -
              num_permutations(num_invisible - num_same_invisible, num_tsumos) /
              num_permutations(num_invisible, num_tsumos).to_f()
          #p [:pai_tsumo_prob, pai, num_invisible, num_same_invisible, num_tsumos, pai_tsumo_prob]
          all_tsumo_prob *= pai_tsumo_prob
        end
        #p [:all_tsumo_prob, required_pais, all_tsumo_prob]
        no_hora_prob *= (1.0 - all_tsumo_prob)
      end
      return 1.0 - no_hora_prob
    end
    
    # This is too slow but left here as most precise baseline.
    def get_hora_prob_with_monte_carlo(tehais, visible_set, num_visible)
      invisibles = []
      for pai in board.all_pais.uniq
        pai = pai.remove_red()
        (4 - visible_set[pai]).times() do
          invisibles.push(pai)
        end
      end
      num_tsumos = board.num_pipais / 4
      hora_freq = 0
      num_tries = 1000
      num_tries.times() do
        tsumos = invisibles.sample(num_tsumos)
        pais = tehais + tsumos
        #p [:pais, pais.sort().join(" ")]
        can_be = can_be_hora?(pais)
        #p [:can_be, can_be]
        next if !can_be
        shanten = ShantenCounter.new(pais, -1, [:normal], 14, false)
        #pp [:shanten, tehais, tsumos, shanten.shanten]
        #if shanten.shanten == -1
        #  pp [:comb, shanten.combinations[0]]
        #end
        hora_freq += 1 if shanten.shanten == -1
      end
      return hora_freq.to_f() / num_tries
    end
    
    def can_be_hora?(pais)
      pai_set = to_pai_set(pais)
      kotsus = pai_set.select(){ |pai, c| c >= 3 }
      toitsus = pai_set.select(){ |pai, c| c >= 2 }
      num_cont = 1
      # TODO 重複を考慮
      num_shuntsus = 0
      pais.map(){ |pai| pai.remove_red() }.sort().uniq().each_cons(2) do |prev_pai, pai|
        if pai.type != "t" && pai.type == prev_pai.type && pai.number == prev_pai.number + 1
          num_cont += 1
          if num_cont >= 3
            num_shuntsus += 1
            num_cont = 0
          end
        else
          num_cont = 1
        end
      end
      return kotsus.size + num_shuntsus >= 4 && toitsus.size >= 1
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
